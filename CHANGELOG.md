# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/).

## 2.2.0 / 2023-10-17
* Add support for `MERGE` (credit: @benalavi)
* Add requirement for `sequel` v5.58.0 or newer (to support the new MERGE methods).

## 2.1.0 / 2022-06-17
* Add support for `EXPLAIN`.

## 2.0.0 / 2021-06-16
* Change LICENSE to MIT (open source).
* This gem is now tested against Rubies 2.6, 2.7, and 3.0.

## 1.0.0 / 2021-04-22 [Initial Release]
* Handle parsing Snowflake values for the following types:
    * Numeric data types
    * String data types
    * Booleans
    * Dates
* Support insertion of multiple rows using the `VALUES` syntax.
* Support creating tables with `String` columns with maximum varchar size (16777216).
