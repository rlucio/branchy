require 'helper'
require 'matrix'

class TestBranchy < Test::Unit::TestCase
  context "create new schedules" do
    setup do
      @s = Object.new
      @s.extend(Branchy)
    end

    context "with valid params" do
      should "create an empty schedule with zero slots" do
        assert_equal nil, @s.schedule_create(0)
        @s.schedule_free()
      end

      should "free an uninitialized schedule" do
        assert_equal nil, @s.schedule_free()
      end

      should "free an initialized schedule" do
        @s.schedule_create(0)
        assert_equal nil, @s.schedule_free()
      end

      should "not add a weight for an uninitialized schedule" do
        assert_equal false, @s.schedule_set_weight([1.0, 2.0, 3.0], [0])
      end

      should "not add a constraint for an uninitialized schedule" do
        assert_equal false, @s.schedule_set_constraints([0])
      end

      should "set a single weight for a simple schedule" do
        @s.schedule_create(1)
        assert_equal true, @s.schedule_set_weight([1.0], [0])
        @s.schedule_free()
      end

      should "set a single weight for a bigger schedule" do
        @s.schedule_create(3)
        assert_equal true, @s.schedule_set_weight([1.0, 2.0, 3.0], [0, 1, 2])
        @s.schedule_free()
      end

      should "set a single constraint for a simple schedule" do
        @s.schedule_create(1)
        assert_equal true, @s.schedule_set_constraints([0])
        @s.schedule_free()
      end

      should "set a single constraint set for a bigger schedule" do
        @s.schedule_create(3)
        assert_equal true, @s.schedule_set_constraints([0, 2, 5])
        @s.schedule_free()
      end
    end

    context "with invalid params" do
      should "not create a schedule without a fixnum" do
        assert_raise TypeError do
          @s.schedule_create("foo")
        end
      end

      should "not set a single weight with a wrong-sized weight set" do
        @s.schedule_create(3)
        assert_equal false, @s.schedule_set_weight([1.0], [0])
        @s.schedule_free()
      end

      should "not set a single weight with an empty weight set" do
        @s.schedule_create(3)
        assert_equal false, @s.schedule_set_weight([], [0])
        @s.schedule_free()
      end

      should "not set a single weight with an empty attribute set" do
        @s.schedule_create(1)
        assert_equal false, @s.schedule_set_weight([1.0], [])
        @s.schedule_free()
      end

      should "not set a single constraint with an empty constraint set" do
        @s.schedule_create(1)
        assert_equal false, @s.schedule_set_constraints([])
        @s.schedule_free()
      end

      #should "not set a single weight with an invalid weight set" do
      #  @s.schedule_create(1)
      #  assert_raise TypeError do
      #    @s.schedule_set_weight(["foo"], [0])
      #  end
      #  @s.schedule_free()
      #end

      should "not set a single weight with an invalid attribute set" do
        @s.schedule_create(1)
        assert_raise TypeError do
          @s.schedule_set_weight([1.0], ["foo"])
        end
        @s.schedule_free()
      end

      should "not set a single constraint with an invalid constraint set" do
        @s.schedule_create(1)
        assert_raise TypeError do
          @s.schedule_set_constraints(["foo"])
        end
        @s.schedule_free()
      end
    end
  end

  context "compute solutions" do
    setup do
      @s = Object.new
      @s.extend(Branchy)
    end

    context "with valid params" do
      should "compute a nil solution for an empty schedule" do
        @s.schedule_create(0)
        assert_equal nil, @s.schedule_compute_solution(1, nil)
        @s.schedule_free()
      end

      should "compute a nil solution for worst-case weights" do
        m = Matrix[
            [ 0, 0, 0, 0 ],
            [ 0, 0, 0, 0 ],
            [ 0, 0, 0, 0 ],
            [ 0, 0, 0, 0 ],
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        assert_equal nil, @s.schedule_compute_solution(1, nil)
        @s.schedule_free()
      end

      should "compute a valid solution for all equal weights" do
        m = Matrix[
            [ 1, 1, 1, 1 ],
            [ 1, 1, 1, 1 ],
            [ 1, 1, 1, 1 ],
            [ 1, 1, 1, 1 ],
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        assert_equal({0=>[0, 2, 1, 3]}, @s.schedule_compute_solution(1, nil))
        @s.schedule_free()
      end

      should "compute a correct solution for a simple set" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        assert_equal({0=>[0, 1, 2, 3]}, @s.schedule_compute_solution(1, nil))
        @s.schedule_free()
      end

      should "return nil solution if schedule constraints cannot be satisfied" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([5])
        end

        @s.schedule_print()
        assert_equal nil, @s.schedule_compute_solution(1, nil)
        @s.schedule_free()
      end

      should "compute a correct solution for a small set" do
        m = Matrix[
            [ 1.201, 1.121, 0.222, 1.122 ],
            [ 1.11 , 1.2  , 1.111, 0.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.222, 1.222, 1.222, 1.222 ]
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        assert_equal({0=>[2, 0, 1, 3]}, @s.schedule_compute_solution(1, nil))
        @s.schedule_free()
      end

      should "compute a correct solution for a larger set" do
        m = Matrix[
            [ 1.201, 1.121, 0.222, 1.122 ],
            [ 1.11 , 1.2  , 1.111, 0.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 0.221, 1.121, 1.202, 1.121 ],
            [ 0.112, 0.022, 0.111, 1.1   ],
            [ 1.121, 1.212, 1.22,  1.212 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.222, 1.222, 1.222, 1.222 ]
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        assert_equal({0=>[2, 3, 4, 9]}, @s.schedule_compute_solution(1, nil))
        @s.schedule_free()
      end


      should "compute a correct solution for a simple set with no constraints" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        @s.schedule_print()
        assert_equal({0=>[0, 1, 2, 3]}, @s.schedule_compute_solution(1, nil))
        @s.schedule_free()
      end

      should "compute a correct solution for a simple set with constraints" do
        # schedule weight set for each entity (two columns means two slots)
        #
        #  entity 0 [ 1.0, 0.0 ],
        #  entity 1 [ 0.0, 1.0 ],
        #  entity 2 [ 1.0, 0.0 ],
        #  entity 3 [ 0.0, 1.0 ],
        #
        # attributes set for each entity, 0=java, 1=rails, 2=engineer
        #
        #  entity 0 [ 0, 2 ],     # java, engineer
        #  entity 1 [ 0, 1, 2 ],  # java, rails, engineer
        #  entity 2 [ 1 ],        # rails
        #  entity 3 [ 1 ],        # rails
        #
        @s.schedule_create(2)
        @s.schedule_set_weight([1.0,0.0], [0,2])
        @s.schedule_set_weight([0.0,1.0], [0,1,2])
        @s.schedule_set_weight([1.0,0.0], [1])
        @s.schedule_set_weight([0.0,1.0], [1])

        # constraints are: 1 'java' 'engineer', 1 'rails'
        #
        @s.schedule_set_constraints([0, 2])
        @s.schedule_set_constraints([1])

        @s.schedule_print()
        weights_hash = {}
        assert_equal({0=>[2, 1]}, @s.schedule_compute_solution(1, weights_hash))
        assert_equal({0=>2.0}, weights_hash)
        @s.schedule_free()
      end

      should "compute multiple solution for a larger set" do
        m = Matrix[
            [ 1.201, 1.121, 0.222, 1.122 ],
            [ 1.11 , 1.2  , 1.111, 0.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 0.221, 1.121, 1.202, 1.121 ],
            [ 0.112, 0.022, 0.111, 1.1   ],
            [ 1.121, 1.212, 1.22,  1.212 ],
            [ 1.212, 1.122, 0.222, 1.122 ],
            [ 1.222, 1.222, 1.222, 1.222 ]
        ]

        @s.schedule_create(m.column_size)

        for i in 0..(m.row_size - 1) do
          @s.schedule_set_weight(m.row(i).to_a, [0])
        end

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        @s.schedule_print()
        weights_hash = {}
        assert_equal({0=>[2, 3, 4, 9], 1=>[2, 4, 3, 9], 2=>[2, 8, 3, 9]}, @s.schedule_compute_solution(3, weights_hash))
        assert_equal({0=>4.8580002784729, 1=>4.8580002784729, 2=>4.8580002784729}, weights_hash)
        @s.schedule_free()
      end
    end

    context "with invalid params" do
      should "return a nil solution when given too few weights to fill a schedule" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)
        @s.schedule_set_weight(m.row(0).to_a, [0])

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        assert_equal nil, @s.schedule_compute_solution(1, nil)
        @s.schedule_free()
      end

      should "return a range error when requesting a negative solution count" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)
        @s.schedule_set_weight(m.row(0).to_a, [0])

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        assert_raise RangeError do
          @s.schedule_compute_solution(-1, nil)
        end
        @s.schedule_free()
      end

      should "return a type error when requesting an invalid solution count" do
        m = Matrix[
            [ 1, 0, 0, 0 ],
            [ 0, 1, 0, 0 ],
            [ 0, 0, 1, 0 ],
            [ 0, 0, 0, 1 ],
        ]

        @s.schedule_create(m.column_size)
        @s.schedule_set_weight(m.row(0).to_a, [0])

        for i in 0..(m.column_size - 1) do
          @s.schedule_set_constraints([0])
        end

        assert_raise TypeError do
          @s.schedule_compute_solution("foo", nil)
        end
        @s.schedule_free()
      end
    end
  end
end
