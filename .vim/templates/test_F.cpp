/*******************************************************************************
 *
 * TRIQS: a Toolbox for Research in Interacting Quantum Systems
 *
 * Copyright (C) 2020 Simons Foundation
 *   author: N. Wentzell
 *
 * TRIQS is free software: you can redistribute it and/or modify it under the
 * terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * TRIQS is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * TRIQS. If not, see <http://www.gnu.org/licenses/>.
 *
 ******************************************************************************/

#include <nda/gtest_tools.hpp>

// Test fixture, common to all tests
class Test_Group : public ::testing::Test {
  protected:
  double my_var;
  virtual void SetUp() { my_var = 1.0; }
  void myfunc() { my_var = 2.0; }
};

TEST_F(Test_Group, Test1) {
  // XXX Do something
  // EXPECT_TRUE( .. );
  // EXPECT_FALSE( .. );
  // EXPECT_EQ( .. );
}

TEST_F(Test_Group, Test2) {
  // XXX Do something
}

MAKE_MAIN;
