class Isomorphism < Formula
  desc "Platform-agnostic C++ math wrapper unifying MLX and SYCL backends"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "71dab3bf971ea5a7c78323aa48e1436653de9038643ea1ca9093de8a4d983c6f" # Generate using 'shasum -a 256' on the tarball
  license "MIT"

  depends_on "cmake" => :build

  # Backend selection: Default to MLX on macOS (Apple Silicon)
  if OS.mac? && Hardware::CPU.arm?
    depends_on "mlx"
  end

  def install
    args = std_cmake_args + %W[
      -DCMAKE_BUILD_TYPE=Release
      -DBUILD_SHARED_LIBS=ON
      -DBUILD_TESTING=OFF
    ]

    # Automatic backend selection based on platform
    if OS.mac? && Hardware::CPU.arm?
      args << "-DUSE_MLX=ON"
    else
      # Assuming SYCL/oneMKL for Linux/PC builds
      args << "-DUSE_SYCL=ON"
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
          // Basic check to ensure the header is reachable
          return 0;
      }
    EOS
    # Link against -lisomorphism
    system ENV.cxx, "-std=c++20", "test.cpp", "-L#{lib}", "-lisomorphism", "-o", "test"
    system "./test"
  end
end
