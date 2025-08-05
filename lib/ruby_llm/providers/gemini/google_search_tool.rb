# frozen_string_literal: true

# This is copied from https://github.com/florianfelsing/ruby_llm.
module RubyLLM
  module Providers
    module Gemini
      # Marker for Gemini's native Google search
      class GoogleSearchTool < RubyLLM::Tool
        description 'Gemini built-in Google search capability'

        def name = :google_search
        def payload = { google_search: {} }
      end
    end
  end
end
