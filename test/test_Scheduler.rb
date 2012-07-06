require 'helper'
require 'matrix'

class TestScheduler < Test::Unit::TestCase
  context "a schedule" do
    setup do
      @s = Object.new
      @s.extend(Scheduler)
    end

    should "give a correct solution for a small set" do
      m = Matrix[
                 [ 1.201, 1.121, 0.222, 1.122 ],
                 [ 1.11 , 1.2  , 1.111, 0.122 ],
                 [ 1.212, 1.122, 0.222, 1.122 ],
                 [ 1.222, 1.222, 1.222, 1.222 ]
                ]

      @s.schedule_create(m.column_size)

      for i in 0..(m.row_size - 1) do
        @s.schedule_set_weight(m.row(i).to_a)
      end

      assert_equal [2, 0, 1, 3], @s.schedule_compute_solution()

      @s.schedule_free()
    end

    should "give a correct solution for a larger set" do
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
        @s.schedule_set_weight(m.row(i).to_a)
      end

      assert_equal [2, 3, 4, 9], @s.schedule_compute_solution()

      @s.schedule_free()
    end
  end
end
