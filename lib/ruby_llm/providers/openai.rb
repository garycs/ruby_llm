# frozen_string_literal: true

module RubyLLM
  module Providers
    # OpenAI API integration. Handles chat completion, function calling,
    # and OpenAI's unique streaming format. Supports GPT-4, GPT-3.5,
    # and other OpenAI models.
    class OpenAI < Provider
      include OpenAI::Chat
      include OpenAI::Embeddings
      include OpenAI::Models
      include OpenAI::Streaming
      include OpenAI::Tools
      include OpenAI::Images
      include OpenAI::Media

      def api_base
        @config.openai_api_base || 'https://api.openai.com/v1'
      end

      def headers
        {
          'Authorization' => "Bearer #{@config.openai_api_key}",
          'OpenAI-Organization' => @config.openai_organization_id,
          'OpenAI-Project' => @config.openai_project_id
        }.compact
      end

      def maybe_normalize_temperature(temperature, model_id)
        OpenAI::Capabilities.normalize_temperature(temperature, model_id)
      end

      class << self
        def capabilities
          OpenAI::Capabilities
        end

        def configuration_requirements
          %i[openai_api_key]
        end
      end
    end
  end
end
