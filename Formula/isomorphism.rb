class Isomorphism < Formula
  desc "Hardware-agnostic C++ tensor math library with pluggable backends (MLX, Eigen, Torch)"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "f7da8210fe108ca1dcb7ef61e0258bd103c85e11a086420b8960079c6a9741ad"
  license "MIT"

  # ---------------------------------------------------------------------------
  # Backend options — one or more may be selected simultaneously.
  # Each produces its own library: libisomorphism_mlx, libisomorphism_eigen, …
  #
  # Usage:
  #   brew install isomorphism                              # auto: mlx on Apple Silicon, eigen elsewhere
  #   brew install isomorphism --with-mlx                  # Apple Silicon GPU (MLX)
  #   brew install isomorphism --with-eigen                # CPU (Eigen)
  #   brew install isomorphism --with-torch                # PyTorch / LibTorch
  #   brew install isomorphism --with-mlx --with-torch     # both simultaneously
  # ---------------------------------------------------------------------------
  option "with-mlx",   "Build the Apple Silicon (MLX/Metal) backend"
  option "with-eigen", "Build the Eigen CPU backend"
  option "with-torch", "Build the PyTorch (LibTorch) backend"

  depends_on "cmake" => :build
  depends_on "libomp"

  # Determine whether auto-selection applies (no explicit backend chosen)
  _none_explicit = build.without?("mlx") && build.without?("eigen") && build.without?("torch")

  # Backend dependencies — only pulled in for active backends
  depends_on "mlx"     if build.with?("mlx")   || (_none_explicit && OS.mac? && Hardware::CPU.arm?)
  depends_on "eigen"   if build.with?("eigen") || (_none_explicit && !OS.mac?)
  depends_on "pytorch" if build.with?("torch")

  # abseil is a transitive dep of LibTorch's protobuf — CMake needs it to
  # register absl:: targets before find_package(Torch) validates link interfaces.
  depends_on "abseil"  if build.with?("torch")

  # ---------------------------------------------------------------------------
  # Returns the list of backends to build.
  # Falls back to a single auto-selected backend when nothing is explicit.
  # ---------------------------------------------------------------------------
  def selected_backends
    explicit = [:mlx, :eigen, :torch].select { |b| build.with?(b.to_s) }
    return explicit unless explicit.empty?

    # Auto-select: MLX on Apple Silicon, Eigen everywhere else
    [(OS.mac? && Hardware::CPU.arm?) ? :mlx : :eigen]
  end

  # Guard add_subdirectory(tests) on BUILD_TESTING so -DBUILD_TESTING=OFF works.
  patch do
    data
  end

  def install
    # Apple Clang does not ship with OpenMP; point CMake at the Homebrew libomp.
    # These three variables are required for FindOpenMP to succeed on macOS.
    libomp = Formula["libomp"].opt_prefix

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp -I#{libomp}/include",
      "-DOpenMP_CXX_LIB_NAMES=omp",
      "-DOpenMP_omp_LIBRARY=#{libomp}/lib/libomp.dylib",
    ]

    selected_backends.each do |backend|
      case backend
      when :mlx
        args << "-DUSE_MLX=ON"

      when :eigen
        args << "-DUSE_EIGEN=ON"

      when :torch
        args << "-DUSE_TORCH=ON"
        # Point CMake at the Homebrew pytorch and abseil prefixes so that
        # find_package(Torch) and find_package(absl) both succeed without
        # relying on brew being in the build tool's PATH.
        torch_prefix  = Formula["pytorch"].opt_prefix
        abseil_prefix = Formula["abseil"].opt_prefix
        args << "-DCMAKE_PREFIX_PATH=#{torch_prefix};#{abseil_prefix};#{HOMEBREW_PREFIX}"
        args << "-Dabsl_DIR=#{abseil_prefix}/lib/cmake/absl"
      end
    end

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    (testpath/"test.cpp").write <<~EOS
      #include <isomorphism/math.hpp>
      #include <vector>
      int main() {
        auto t = isomorphism::math::full({2, 3}, 1.0f, isomorphism::DType::Float32);
        return t.size() == 6 ? 0 : 1;
      }
    EOS

    # Test against the first installed backend.
    # Each backend installs as libisomorphism_<name> — pick the right one.
    backend = selected_backends.first
    lib_name = "isomorphism_#{backend}"

    backend_flags = case backend
    when :mlx
      mlx = Formula["mlx"].opt_prefix
      "-I#{mlx}/include -L#{mlx}/lib -lmlx"
    when :eigen
      "-I#{Formula["eigen"].opt_include}/eigen3"
    when :torch
      torch = Formula["pytorch"].opt_prefix
      "-I#{torch}/include -I#{torch}/include/torch/csrc/api/include -L#{torch}/lib -ltorch -ltorch_cpu -lc10"
    end

    system ENV.cxx, "-std=c++20", "test.cpp",
           "-I#{include}", "-L#{lib}", "-l#{lib_name}",
           *backend_flags.split, "-o", "test"
    system "./test"
  end
end

__END__
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -284,1 +284,4 @@
-add_subdirectory(tests)
+if (BUILD_TESTING)
+    enable_testing()
+    add_subdirectory(tests)
+endif ()
