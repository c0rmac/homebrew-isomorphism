class IsomorphismEigen < Formula
  desc "Hardware-accelerated C++ tensor math library — Eigen CPU backend"
  homepage "https://github.com/c0rmac/isomorphism"
  url "https://github.com/c0rmac/isomorphism/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "f7da8210fe108ca1dcb7ef61e0258bd103c85e11a086420b8960079c6a9741ad"
  license "MIT"

  depends_on "cmake" => :build
  depends_on "libomp"
  depends_on "eigen"

  # Guard add_subdirectory(tests) on BUILD_TESTING so -DBUILD_TESTING=OFF works.
  patch :DATA

  def install
    libomp = Formula["libomp"].opt_prefix
    eigen  = Formula["eigen"].opt_include

    args = std_cmake_args + [
      "-DCMAKE_BUILD_TYPE=Release",
      "-DBUILD_SHARED_LIBS=ON",
      "-DBUILD_TESTING=OFF",
      "-DUSE_EIGEN=ON",
      "-DCMAKE_PREFIX_PATH=#{Formula["eigen"].opt_prefix};#{HOMEBREW_PREFIX}",
      "-DOpenMP_CXX_FLAGS=-Xpreprocessor -fopenmp -I#{libomp}/include",
      "-DOpenMP_CXX_LIB_NAMES=omp",
      "-DOpenMP_omp_LIBRARY=#{libomp}/lib/libomp.dylib",
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    eigen = Formula["eigen"].opt_include

    (testpath/"test.cpp").write <<~EOS
      #include <isomorphism/math.hpp>
      #include <vector>
      int main() {
        auto t = isomorphism::math::full({2, 3}, 1.0f, isomorphism::DType::Float32);
        return t.size() == 6 ? 0 : 1;
      }
    EOS

    system ENV.cxx, "-std=c++20", "test.cpp",
           "-I#{include}",
           "-I#{eigen}/eigen3",
           "-L#{lib}", "-lisomorphism_eigen",
           "-o", "test"
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
