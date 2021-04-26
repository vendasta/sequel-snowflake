require 'securerandom'

describe Sequel::Snowflake::Dataset do
  describe 'Converting Snowflake data types' do
    # Create a test table with a reasonably-random suffix
    let!(:test_table) { "SEQUEL_SNOWFLAKE_SPECS_#{SecureRandom.hex(10)}" }

    it 'converts Snowflake data types into equivalent Ruby types' do
      # Set timezone for parsing timestamps. This gives us a consistent timezone
      # to test against below.
      Sequel.default_timezone = :utc

      Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR']) do |db|
        db.run(
          "CREATE TEMP TABLE #{test_table} (
            n number, d number(38,5), f float, t timestamp, b boolean, str string, str2 string
          )"
        )

        db.run(
          "INSERT INTO #{test_table} (n, d, f, t, b, str, str2) values (
            17, 42.035, 1.2247, '2020-03-12 01:02:03.123456789', true, 'hi', null
          )"
        )

        res = db.fetch(
          "SELECT n, d, f, t, b, TO_TIME(t) as time, TO_DATE(t) as date, str, str2 FROM #{test_table} LIMIT 1"
        ).all

        # Since we do some parsing/transformations here, I couldn't do `expect(res[0]).to_match` here.
        expect(res[0][:n]).to eq(17)
        expect(res[0][:d]).to be_within(0.0001).of(42.035)
        expect(res[0][:f]).to be_within(0.00001).of(1.2247)
        expect(res[0][:t].to_f).to be_within(0.001).of(Time.parse('2020-03-12T01:02:03.123Z').to_f)
        expect(res[0][:b]).to eq(true)
        expect(res[0][:time].to_s).to eq('01:02:03')
        expect(res[0][:date].to_s).to eq('2020-03-12')
        expect(res[0][:str]).to eq('hi')
        expect(res[0][:str2]).to eq(nil)

        db.run("DROP TABLE #{test_table}")
      end
    end

    it 'inserts multiple records successfully using the VALUE syntax' do
      Sequel.connect(adapter: :snowflake, drvconnect: ENV['SNOWFLAKE_CONN_STR']) do |db|
        db.run(
          "CREATE TEMP TABLE #{test_table} (
            n number, d number(38,5), f float, t timestamp, b boolean, str string, str2 string
          )"
        )

        db[test_table.to_sym].multi_insert(
          [
            { n: 17, d: 42.035, f: 1.2247, t: '2020-03-12 01:02:03.123456789', b: true, str: 'hi', str2: nil },
            { n: 18, d: 837.5, f: 3.09, t: '2020-03-15 11:22:33.12345', b: false, str: 'beware the ides', str2: 'of march' }
          ]
        )

        res = db.fetch("SELECT count(*) as count FROM #{test_table}").all

        expect(res[0][:count]).to eq(2)

        db.run("DROP TABLE #{test_table}")
      end
    end
  end
end
