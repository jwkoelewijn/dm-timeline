# Define maximum and minimum DateTime objects for various
# adapters. We could also use nil for this, but using explicit
# values makes generating the conditions a lot easier.
module DataMapper
  module Adapters

    class AbstractAdapter
      START_OF_TIME = Date.civil(1901, 12, 13)
      END_OF_TIME   = Date.civil(2038,  1, 19)
    end

    class Sqlite3Adapter
      START_OF_TIME = Date.civil(-4712,  1,  1)
      END_OF_TIME   = Date.civil( 9999, 12, 31)
    end

    class MysqlAdapter
      START_OF_TIME = Date.civil(    0,  1,  1)
      END_OF_TIME   = Date.civil( 9999, 12, 31)
    end

    class PostgresAdapter
      START_OF_TIME = Date.civil(    1,  1,  1)
      END_OF_TIME   = Date.civil( 9999, 12, 31)
    end

  end
end
