class IsomorphismMlx < Formula
  desc "Hardware-accelerated C++ tensor math library — Apple MLX (Metal) backend"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v1.2.0.tar.gz"
  sha256 "42e1bbce18846c45d3ef256473c350274f85f46569a0928d0ec2f0755ca1c415"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "c0rmac/metal-linalg/metal-linalg" # the decompositions and solves, on the GPU and the CPU
  depends_on "libomp"
  depends_on "mlx"

  def install
    libomp = Formula["libomp"].opt_prefix

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_MLX=ON",
      "-DMETAL_LINALG_USE_INSTALLED=ON", # the dependency above; Homebrew builds have no network
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp -I#{libomp}/include",
      "-DOpenMP_CXX_LIB_NAMES=omp",
      "-DOpenMP_omp_LIBRARY=#{libomp}/lib/libomp.dylib",
    ]

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

    system ENV.cxx, "-std=c++20", "test.cpp",
           "-I#{include}", "-L#{lib}", "-lisomorphism_mlx",
           "-I#{Formula["mlx"].opt_include}",
           "-L#{Formula["mlx"].opt_lib}", "-lmlx",
           "-o", "test"
    system "./test"
  end
end
