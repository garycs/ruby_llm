---
layout: default
title: Model Registry
nav_order: 4
description: Access hundreds of AI models from all major providers with one simple API
redirect_from:
  - /guides/models
---

# {{ page.title }}
{: .no_toc }

{{ page.description }}
{: .fs-6 .fw-300 }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

After reading this guide, you will know:

*   How RubyLLM discovers and registers models.
*   How to find and filter available models based on provider, type, or capabilities.
*   How to understand model capabilities and pricing using `Model::Info`.
*   How to use model aliases for convenience.
*   How to connect to custom endpoints (like Azure OpenAI or proxies) using `openai_api_base`.
*   How to use models not listed in the default registry using `assume_model_exists`.

## The Model Registry

RubyLLM maintains an internal registry of known AI models, typically stored in `lib/ruby_llm/models.json` within the gem. This registry is populated by running the `rake models:update` task, which queries the APIs of configured providers to discover their available models and capabilities.

The registry stores crucial information about each model, including:

*   **`id`**: The unique identifier used by the provider (e.g., `gpt-4o-2024-08-06`).
*   **`provider`**: The source provider (`openai`, `anthropic`, etc.).
*   **`type`**: The model's primary function (`chat`, `embedding`, etc.).
*   **`name`**: A human-friendly name.
*   **`context_window`**: Max input tokens (e.g., `128_000`).
*   **`max_tokens`**: Max output tokens (e.g., `16_384`).
*   **`supports_vision`**: If it can process images.
*   **`supports_functions`**: If it can use [Tools]({% link _core_features/tools.md %}).
*   **`input_price_per_million`**: Cost in USD per 1 million input tokens.
*   **`output_price_per_million`**: Cost in USD per 1 million output tokens.
*   **`family`**: A broader classification (e.g., `gpt4o`).

This registry allows RubyLLM to validate models, route requests correctly, provide capability information, and offer convenient filtering.

You can see the full list of currently registered models in the [Available Models Guide]({% link _reference/available-models.md %}).

### Refreshing the Registry

**For Application Developers:**

The recommended way to refresh models in your application is to call `RubyLLM.models.refresh!` directly:

```ruby
# In your application code (console, background job, etc.)
RubyLLM.models.refresh!
puts "Refreshed in-memory model list."
```

This refreshes the in-memory model registry and is what you want 99% of the time. This method is safe to call from Rails applications, background jobs, or any running Ruby process.

**For Gem Development:**

The `rake models:update` task is designed for gem maintainers and updates the `models.json` file shipped with the gem:

```bash
# Only for gem development - requires API keys and gem directory structure
bundle exec rake models:update
```

This task is not intended for Rails applications as it writes to gem directories and requires the full gem development environment.

**Persisting Models to Your Database:**

If you want to store model information in your application's database for persistence, querying, or caching, create your own migration and sync logic. Here's an example schema and production-ready sync job:

```ruby
# db/migrate/xxx_create_llm_models.rb
create_table "llm_models", force: :cascade do |t|
  t.string "model_id", null: false
  t.string "name", null: false
  t.string "provider", null: false
  t.boolean "available", default: false
  t.boolean "is_default", default: false
  t.datetime "last_synced_at"
  t.integer "context_window"
  t.integer "max_output_tokens"
  t.jsonb "metadata", default: {}
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.string "slug"
  t.string "model_type"
  t.string "family"
  t.datetime "model_created_at"
  t.date "knowledge_cutoff"
  t.jsonb "modalities", default: {}, null: false
  t.jsonb "capabilities", default: [], null: false
  t.jsonb "pricing", default: {}, null: false

  t.index ["model_id"], unique: true
  t.index ["provider", "available", "context_window"]
  t.index ["capabilities"], using: :gin
  t.index ["modalities"], using: :gin
  t.index ["pricing"], using: :gin
end

# app/jobs/sync_llm_models_job.rb
class SyncLLMModelsJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 1.seconds, attempts: 5

  def perform
    RubyLLM.models.refresh!

    found_model_ids = RubyLLM.models.chat_models.filter_map do |model_data|
      attributes = model_data.to_h
      attributes[:model_id] = attributes.delete(:id)
      attributes[:model_type] = attributes.delete(:type)
      attributes[:model_created_at] = attributes.delete(:created_at)
      attributes[:last_synced_at] = Time.now

      model = LLMModel.find_or_initialize_by(model_id: attributes[:model_id])
      model.assign_attributes(**attributes)
      model.save ? model.id : nil
    end

    # Mark missing models as unavailable instead of deleting them
    LLMModel.where.not(id: found_model_ids).update_all(available: false)
  end
end

# Schedule it to run periodically
# config/schedule.rb (with whenever gem)
every 6.hours do
  runner "SyncLLMModelsJob.perform_later"
end
```

## Exploring and Finding Models

Use `RubyLLM.models` to explore the registry.

### Listing and Filtering

```ruby
# Get a collection of all registered models
all_models = RubyLLM.models.all

# Filter by type
chat_models = RubyLLM.models.chat_models
embedding_models = RubyLLM.models.embedding_models

# Filter by provider
openai_models = RubyLLM.models.by_provider(:openai) # or 'openai'

# Filter by model family (e.g., all Claude 3 Sonnet variants)
claude3_sonnet_family = RubyLLM.models.by_family('claude3_sonnet')

# Chain filters and use Enumerable methods
openai_vision_models = RubyLLM.models.by_provider(:openai)
                                   .select(&:supports_vision?)

puts "Found #{openai_vision_models.count} OpenAI vision models."
```

### Finding a Specific Model

Use `find` to get a `Model::Info` object containing details about a specific model.

```ruby
# Find by exact ID or alias
model_info = RubyLLM.models.find('gpt-4o')

if model_info
  puts "Model: #{model_info.name}"
  puts "Provider: #{model_info.provider}"
  puts "Context Window: #{model_info.context_window} tokens"
else
  puts "Model not found."
end

# Find raises ModelNotFoundError if the ID is unknown
# RubyLLM.models.find('no-such-model-exists') # => raises ModelNotFoundError
```

### Model Aliases

RubyLLM uses aliases (defined in `lib/ruby_llm/aliases.json`) for convenience, mapping common names to specific versions.

```ruby
# 'claude-3-5-sonnet' might resolve to 'claude-3-5-sonnet-20241022'
chat = RubyLLM.chat(model: 'claude-3-5-sonnet')
puts chat.model.id # => "claude-3-5-sonnet-20241022" (or latest version)
```

`find` prioritizes exact ID matches before falling back to aliases.

### Provider-Specific Resolution

Specify the provider if the same alias exists across multiple providers.

```ruby
# Get Claude 3.5 Sonnet from Anthropic
model_anthropic = RubyLLM.models.find('claude-3-5-sonnet', :anthropic)

# Get Claude 3.5 Sonnet via AWS Bedrock
model_bedrock = RubyLLM.models.find('claude-3-5-sonnet', :bedrock)
```

## Connecting to Custom Endpoints & Using Unlisted Models
{: .d-inline-block }

Sometimes you need to interact with models or endpoints not covered by the standard registry, such as:

*   Azure OpenAI Service endpoints.
*   API Proxies & Gateways (LiteLLM, Fastly AI Accelerator).
*   Self-Hosted/Local Models (LM Studio, Ollama via OpenAI adapter).
*   Brand-new model releases.
*   Custom fine-tunes or deployments with unique names.

RubyLLM offers two mechanisms for these cases:

### Custom OpenAI API Base URL (`openai_api_base`)

If you need to target an endpoint that uses the **OpenAI API format** but has a different URL, configure `openai_api_base` in `RubyLLM.configure`.

```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['AZURE_OPENAI_KEY'] # Key for your endpoint
  config.openai_api_base = "https://YOUR_AZURE_RESOURCE.openai.azure.com" # Your endpoint
end
```

*   This setting **only** affects requests made with `provider: :openai`.
*   It directs those requests to your specified URL instead of `https://api.openai.com/v1`.
*   See [Configuration Guide]({% link _getting_started/configuration.md %}).

### Assuming Model Existence (`assume_model_exists`)

To use a model identifier not listed in RubyLLM's registry, use the `assume_model_exists: true` flag. This tells RubyLLM to bypass its validation check.

```ruby
# Example: Using a custom Azure deployment name
# Assumes openai_api_base is configured for your Azure endpoint
chat = RubyLLM.chat(
  model: 'my-company-secure-gpt4o', # Your custom deployment name
  provider: :openai,                # MUST specify provider
  assume_model_exists: true         # Bypass registry check
)
response = chat.ask("Internal knowledge query...")
puts response.content

# You can also use it in .with_model
chat.with_model(
  'gpt-5-alpha',
  provider: :openai,                # MUST specify provider
  assume_exists: true
)
```

The `assume_model_exists` flag also works with `RubyLLM.embed` and `RubyLLM.paint` for embedding and image generation models:

```ruby
# Custom embedding model
embedding = RubyLLM.embed(
  "Test text",
  model: 'my-custom-embedder',
  provider: :openai,
  assume_model_exists: true
)

# Custom image model
image = RubyLLM.paint(
  "A beautiful landscape",
  model: 'my-custom-dalle',
  provider: :openai,
  assume_model_exists: true
)
```

**Key Points when Assuming Existence:**

*   **`provider:` is Mandatory:** You must tell RubyLLM which API format to use (`ArgumentError` otherwise).
*   **No Validation:** RubyLLM won't check the registry for the model ID.
*   **Capability Assumptions:** Capability checks (like `supports_functions?`) are bypassed by assuming `true`. You are responsible for ensuring the model supports the features you use.
*   **Your Responsibility:** Ensure the model ID is correct for the target endpoint.
*   **Warning Log:** A warning is logged indicating validation was skipped.

Use these features when the standard registry doesn't cover your specific model or endpoint needs. For standard models, rely on the registry for validation and capability awareness. See the [Chat Guide]({% link _core_features/chat.md %}) for more on using the `chat` object.