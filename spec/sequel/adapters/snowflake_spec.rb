require 'securerandom'

describe Sequel::Snowflake::Dataset do
  let(:db) { @db ||= Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR']) }
  
  before(:all) do
    @db = Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR'])
  end
  
  after(:all) do
    @db.disconnect if @db
  end

  describe 'Converting Snowflake data types' do
    # Create a test table with a reasonably-random suffix
    let(:test_table) { "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym }

    before(:each) do
      # Set timezone for parsing timestamps. This gives us a consistent timezone to test against below.
      Sequel.default_timezone = :utc

      db.create_table(test_table, :temp => true) do
        Numeric :n
        BigDecimal :d, size: [38, 5]
        Float :f
        DateTime :t
        TrueClass :b
        String :str
        String :str2
      end
    end

    after(:each) do
      db.drop_table(test_table)
    end

    it 'converts Snowflake data types into equivalent Ruby types' do
      db[test_table].insert(
        { n: 17, d: 42.035, f: 1.2247, t: '2020-03-12 01:02:03.123456789', b: true, str: 'hi', str2: nil }
      )

      res = db[test_table].select(
        :n, :d, :f, :t, :b,
        Sequel.as(Sequel.function(:to_time, :t), :time),
        Sequel.as(Sequel.function(:to_date, :t), :date),
        :str, :str2
      ).first

      expect(res).to include(
        n: 17,
        d: a_value_within(0.0001).of(42.035),
        f: a_value_within(0.00001).of(1.2247),
        b: true,
        str: 'hi',
        str2: nil
      )

      expect(res[:t]).to be_a(Time)
      expect(res[:t].iso8601).to eq('2020-03-12T01:02:03Z')

      expect(res[:time]).to be_a(Time)
      expect(res[:time].to_s).to eq('01:02:03')

      expect(res[:date]).to be_a(Date)
      expect(res[:date].to_s).to eq('2020-03-12')
    end

    it 'inserts multiple records successfully using the VALUE syntax' do
      db[test_table].multi_insert(
        [
          { n: 17, d: 42.035, f: 1.2247, t: '2020-03-12 01:02:03.123456789', b: true, str: 'hi', str2: nil },
          { n: 18, d: 837.5, f: 3.09, t: '2020-03-15 11:22:33.12345', b: false, str: 'beware the ides', str2: 'of march' }
        ]
      )

      expect(db[test_table].count).to eq(2)
      expect(db[test_table].select(:n).all).to eq([{ n: 17 }, { n: 18 }])
    end
  end

  describe 'GROUP BY features' do
    before(:all) do
      @products = "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym
      @sales = "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym

      @db.create_table(@products, :temp => true) do
        Integer :product_id
        Float :wholesale_price
      end

      @db.create_table(@sales, :temp => true) do
        Integer :product_id
        Float :retail_price
        Integer :quantity
        String :city
        String :state
      end

      @db[@products].insert({ product_id: 1, wholesale_price: 1.00 })
      @db[@products].insert({ product_id: 2, wholesale_price: 2.00 })
      @db[@sales].insert({ product_id: 1, retail_price: 2.00, quantity: 1, city: 'SF', state: 'CA' })
      @db[@sales].insert({ product_id: 1, retail_price: 2.00, quantity: 2, city: 'SJ', state: 'CA' })
      @db[@sales].insert({ product_id: 2, retail_price: 5.00, quantity: 4, city: 'SF', state: 'CA' })
      @db[@sales].insert({ product_id: 2, retail_price: 5.00, quantity: 8, city: 'SJ', state: 'CA' })
      @db[@sales].insert({ product_id: 2, retail_price: 5.00, quantity: 16, city: 'Miami', state: 'FL' })
      @db[@sales].insert({ product_id: 2, retail_price: 5.00, quantity: 32, city: 'Orlando', state: 'FL' })
      @db[@sales].insert({ product_id: 2, retail_price: 5.00, quantity: 64, city: 'SJ', state: 'CA' })
    end

    after(:all) do
      @db.drop_table(@products) if @products
      @db.drop_table(@sales) if @sales
    end

    let(:products) { @products }
    let(:sales) { @sales }

    it 'can use GROUP CUBE' do
      res = db.from(Sequel[products].as(:p)).
        join(Sequel[sales].as(:s), Sequel[:p][:product_id] => Sequel[:s][:product_id]).
        select(
          Sequel[:s][:state],
          Sequel[:s][:city],
          Sequel.function(:sum, Sequel.*(Sequel.-(Sequel[:s][:retail_price], Sequel[:p][:wholesale_price]), Sequel[:s][:quantity])).as(:profit)
        ).
        group(Sequel[:s][:state], Sequel[:s][:city]).
        group_cube.
        order(Sequel.asc(Sequel[:s][:state], nulls: :last)).
        order_append(Sequel[:s][:city]).
        all

      expect(res).to match_array([
        { state: 'CA', city: 'SF', profit: 13 },
        { state: 'CA', city: 'SJ', profit: 218 },
        { state: 'CA', city: nil, profit: 231 },
        { state: 'FL', city: 'Miami', profit: 48 },
        { state: 'FL', city: 'Orlando', profit: 96 },
        { state: 'FL', city: nil, profit: 144 },
        { state: nil, city: 'Miami', profit: 48 },
        { state: nil, city: 'Orlando', profit: 96 },
        { state: nil, city: 'SF', profit: 13 },
        { state: nil, city: 'SJ', profit: 218 },
        { state: nil, city: nil, profit: 375 },
      ])
    end

    it 'can use GROUP ROLLUP' do
      res = db.from(Sequel[products].as(:p)).
        join(Sequel[sales].as(:s), Sequel[:p][:product_id] => Sequel[:s][:product_id]).
        select(
          Sequel[:s][:state],
          Sequel[:s][:city],
          Sequel.function(:sum, Sequel.*(Sequel.-(Sequel[:s][:retail_price], Sequel[:p][:wholesale_price]), Sequel[:s][:quantity])).as(:profit)
        ).
        group(Sequel[:s][:state], Sequel[:s][:city]).
        group_rollup.
        order(Sequel.asc(Sequel[:s][:state], nulls: :last)).
        order_append(Sequel[:s][:city]).
        all

      expect(res).to match_array([
        { state: 'CA', city: 'SF', profit: 13 },
        { state: 'CA', city: 'SJ', profit: 218 },
        { state: 'CA', city: nil, profit: 231 },
        { state: 'FL', city: 'Miami', profit: 48 },
        { state: 'FL', city: 'Orlando', profit: 96 },
        { state: 'FL', city: nil, profit: 144 },
        { state: nil, city: nil, profit: 375 },
      ])
    end

    it 'can use GROUPING SETS' do
      res = db.from(Sequel[products].as(:p)).
        join(Sequel[sales].as(:s), Sequel[:p][:product_id] => Sequel[:s][:product_id]).
        select(
          Sequel[:s][:state],
          Sequel[:s][:city],
          Sequel.function(:sum, Sequel.*(Sequel.-(Sequel[:s][:retail_price], Sequel[:p][:wholesale_price]), Sequel[:s][:quantity])).as(:profit)
        ).
        group([Sequel[:s][:state]], [Sequel[:s][:city]]).
        grouping_sets.
        order(Sequel.asc(Sequel[:s][:state], nulls: :last)).
        order_append(Sequel[:s][:city]).
        all

      expect(res).to match_array([
        { state: 'CA', city: nil, profit: 231 },
        { state: 'FL', city: nil, profit: 144 },
        { state: nil, city: 'Miami', profit: 48 },
        { state: nil, city: 'Orlando', profit: 96 },
        { state: nil, city: 'SF', profit: 13 },
        { state: nil, city: 'SJ', profit: 218 },
      ])
    end
  end

  describe 'MERGE feature' do
    before(:all) do
      @target_table = "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym
      @source_table = "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym

      @db.create_table(@target_table, :temp => true) do
        String :str
        String :str2
        String :str3
      end

      @db.create_table(@source_table, :temp => true) do
        String :from
        String :to
        String :whomst
      end
    end

    after(:all) do
      @db.drop_table(@target_table) if @target_table
      @db.drop_table(@source_table) if @source_table
    end

    before(:each) do
      # Clear and repopulate data for each test since MERGE modifies data
      db[@target_table].delete
      db[@source_table].delete
      db[@target_table].insert({ str: 'foo', str2: 'foo', str3: 'phoo' })
      db[@target_table].insert({ str: 'baz', str2: 'foo', str3: 'buzz' })
      db[@source_table].insert({ from: 'foo', to: 'bar', whomst: 'me' })
    end

    let(:target_table) { @target_table }
    let(:source_table) { @source_table }

    it 'can use MERGE' do
      db[target_table].merge_using(source_table, str: :from).merge_update(str2: :to).merge

      expect(db[target_table].select_all.all).to match_array([
        { str: 'foo', str2: 'bar', str3: 'phoo' },
        { str: 'baz', str2: 'foo', str3: 'buzz' }
      ])
    end
  end

  describe '#explain' do
    before(:all) do
      @test_table = "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym

      @db.create_table(@test_table, :temp => true) do
        Numeric :id
        String :name
        String :email
        String :title
      end

      @db[@test_table].insert(
        { id: 1, name: 'John Null', email: 'j.null@example.com', title: 'Software Tester' }
      )
    end

    after(:all) do
      @db.drop_table(@test_table) if @test_table
    end

    let(:test_table) { @test_table }

    it "should have explain output" do
      query = db.fetch("SELECT * FROM #{test_table} WHERE ID=1;")

      expect(query.explain).to be_a_kind_of(String)
      expect(query.explain(:tabular=>true)).to be_a_kind_of(String)
      expect(query.explain(:json=>true)).to be_a_kind_of(String)
      expect(query.explain(:text=>true)).to be_a_kind_of(String)
    end
  end
end
