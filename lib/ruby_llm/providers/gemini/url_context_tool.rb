# frozen_string_literal: true

# This is inspired from https://github.com/florianfelsing/ruby_llm.
module RubyLLM
  module Providers
    class Gemini
      # Marker for Gemini's native Google search
      class UrlContextTool < RubyLLM::Tool
        description 'Gemini built-in URL Context capability'

        def name = :url_context
        def payload = { url_context: {} }
      end
    end
  end
end

