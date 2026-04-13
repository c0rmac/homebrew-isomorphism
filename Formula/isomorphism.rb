class Isomorphism < Formula
  desc "Hardware-agnostic C++ tensor math library with pluggable backends (MLX, Eigen, Torch)"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "4d76ebe16b560e48a84a9095054aa70b06964b62621e52738bbe5769d2d54b8c"
  license "MIT"

  # ---------------------------------------------------------------------------
  # Backend options — exactly one must be chosen.
  # Usage:
  #   brew install isomorphism                        # auto: mlx on Apple Silicon, eigen elsewhere
  #   brew install isomorphism --with-mlx             # Apple Silicon GPU (MLX)
  #   brew install isomorphism --with-eigen           # CPU (Eigen)
  #   brew install isomorphism --with-torch           # PyTorch / LibTorch
  # ---------------------------------------------------------------------------
  option "with-mlx",   "Build with the Apple Silicon (MLX/Metal) backend"
  option "with-eigen", "Build with the Eigen CPU backend"
  option "with-torch", "Build with the PyTorch (LibTorch) backend"

  depends_on "cmake" => :build

  # Backend dependencies — only pulled in when the matching option is active
  depends_on "mlx"     if build.with?("mlx")   || (build.without?("eigen") && build.without?("torch") && OS.mac? && Hardware::CPU.arm?)
  depends_on "eigen"   if build.with?("eigen") || (build.without?("mlx")   && build.without?("torch") && !OS.mac?)
  depends_on "pytorch" if build.with?("torch")

  # abseil is a transitive dep of LibTorch's protobuf — must be present so
  # CMake can register the absl:: targets before find_package(Torch) runs.
  depends_on "abseil"  if build.with?("torch")

  # ---------------------------------------------------------------------------
  # Determine the active backend, enforcing that exactly one is selected
  # ---------------------------------------------------------------------------
  def active_backend
    explicit = [:mlx, :eigen, :torch].select { |b| build.with?(b.to_s) }

    if explicit.size > 1
      odie "isomorphism: specify only one backend (--with-mlx, --with-eigen, or --with-torch)."
    end

    if explicit.size == 1
      return explicit.first
    end

    # Auto-select: MLX on Apple Silicon, Eigen everywhere else
    (OS.mac? && Hardware::CPU.arm?) ? :mlx : :eigen
  end

  def install
    backend = active_backend

    args = std_cmake_args + %W[
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
    ]

    case backend
    when :mlx
      args << "-DUSE_MLX=ON"
    when :eigen
      args << "-DUSE_EIGEN=ON"
    when :torch
      args << "-DUSE_TORCH=ON"
      # Point CMake at the Homebrew pytorch and abseil prefixes so that
      # find_package(Torch) and find_package(absl) both succeed.
      torch_prefix  = Formula["pytorch"].opt_prefix
      abseil_prefix = Formula["abseil"].opt_prefix
      args << "-DCMAKE_PREFIX_PATH=#{torch_prefix};#{abseil_prefix}"
      args << "-Dabsl_DIR=#{abseil_prefix}/lib/cmake/absl"
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

    # Resolve the include/lib paths for the active backend so the test compiles
    backend_flags = case active_backend
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
           "-I#{include}", "-L#{lib}", "-lisomorphism",
           *backend_flags.split, "-o", "test"
    system "./test"
  end
end
