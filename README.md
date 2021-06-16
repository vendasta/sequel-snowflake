# sequel-snowflake

An adapter to connect to Snowflake databases using [Sequel](http://sequel.jeremyevans.net/).
This provides proper types for returned values, as opposed to the ODBC adapter.

[![Ruby](https://github.com/Yesware/sequel-snowflake/actions/workflows/ruby.yml/badge.svg)](https://github.com/Yesware/sequel-snowflake/actions/workflows/ruby.yml)

## Installation

Add this line to your application's Gemfile:

    gem 'sequel-snowflake'

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install sequel-snowflake

You'll also need [unixODBC](http://www.unixodbc.org/) (if on Linux/macOS) and the appropriate
[Snowflake ODBC driver](https://sfc-repo.snowflakecomputing.com/odbc/index.html) in order to use
this adapter. Follow the Snowflake documentation on their ODBC Driver
[here](https://docs.snowflake.com/en/user-guide/odbc.html) before proceeding.

## Usage

When establishing the connection, specify `:snowflake` as the adapter to use.

```ruby
DB = Sequel.connect(adapter: :snowflake,
                    drvconnect: conn_str)
```

## Testing

In order to run specs, you'll need a Snowflake account. A connection string should be
provided as an environment variable `SNOWFLAKE_CONN_STR`. For example, on macOS,
our connection string would resemble:

```bash
DRIVER=/opt/snowflake/snowflakeodbc/lib/universal/libSnowflake.dylib;
SERVER=<account>.<region>.snowflakecomputing.com;
DATABASE=<database>;
WAREHOUSE=<warehouse>;
SCHEMA=<schema>;
UID=<user>;
PWD=<password>;
CLIENT_SESSION_KEEP_ALIVE=true;
```

The test will create a temporary table on the specified database to run tests on, and this will
be taken down either via the `after(:each)` blocks or when the connection is closed.

## Contributing

1. Fork it ( https://github.com/Yesware/sequel-snowflake/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
