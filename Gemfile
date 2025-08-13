# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do # rubocop:disable Metrics/BlockLength
  gem 'appraisal'
  gem 'async', platform: :mri
  gem 'bundler', '>= 2.0'
  gem 'codecov'
  gem 'dotenv'
  gem 'ferrum'
  gem 'flay'
  gem 'irb'
  gem 'json-schema'
  gem 'nokogiri'
  gem 'overcommit', '>= 0.66'
  gem 'pry', '>= 0.14'
  gem 'rails'
  gem 'rake', '>= 13.0'
  gem 'reline'
  gem 'rspec', '~> 3.12'
  gem 'rubocop', '>= 1.0'
  gem 'rubocop-rake', '>= 0.6'
  gem 'rubocop-rspec'
  gem 'ruby_llm-schema', '~> 0.1.0'
  gem 'simplecov', '>= 0.21'
  gem 'simplecov-cobertura'

  # database drivers for MRI and JRuby
  gem 'activerecord-jdbcsqlite3-adapter', platform: 'jruby'
  gem 'jdbc-sqlite3', platform: 'jruby'
  gem 'sqlite3', platform: 'mri'

  gem 'vcr'
  gem 'webmock', '~> 3.18'
end
