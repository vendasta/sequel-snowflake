require 'securerandom'

describe Sequel::Snowflake::Dataset do
  describe 'Converting Snowflake data types' do
    # Create a test table with a reasonably-random suffix
    let!(:test_table) { "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym }
    let!(:db) { Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR']) }

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

    it 'can use MERGE' do
      merge_table = "#{test_table}_MERGE".to_sym

      db.create_table(merge_table, :temp => true) do
        String :from
        String :to
      end

      db[test_table].insert({ str: 'foo', str2: 'foo' })
      db[merge_table].insert({ from: 'foo', to: 'bar' })
      db[test_table].merge_using(merge_table, str: :from).merge_update(str2: :to).merge

      expect(db[test_table].select_map(:str2)).to eq(['bar'])

      db.drop_table(merge_table)
    end
  end

  describe '#explain' do
    # Create a test table with a reasonably-random suffix
    let!(:test_table) { "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}".to_sym }
    let!(:db) { Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR']) }

    before(:each) do
      db.create_table(test_table, :temp => true) do
        Numeric :id
        String :name
        String :email
        String :title
      end

      db[test_table].insert(
        { id: 1, name: 'John Null', email: 'j.null@example.com', title: 'Software Tester' }
      )
    end

    after(:each) do
      db.drop_table(test_table)
    end

    it "should have explain output" do
      query = db.fetch("SELECT * FROM #{test_table} WHERE ID=1;")

      expect(query.explain).to be_a_kind_of(String)
      expect(query.explain(:tabular=>true)).to be_a_kind_of(String)
      expect(query.explain(:json=>true)).to be_a_kind_of(String)
      expect(query.explain(:text=>true)).to be_a_kind_of(String)
    end
  end
end
