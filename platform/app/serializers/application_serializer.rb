# frozen_string_literal: true

# Every Inertia prop that comes from a model goes through a serializer, so the browser only ever sees
# what is listed here and typelizer can generate matching TypeScript interfaces.
class ApplicationSerializer
  include Alba::Resource
  include Typelizer::DSL

  helper do
    # Serialize a single record or a collection to a plain Hash/Array for `render inertia:`.
    def render(object, **params)
      new(object, params: params).serializable_hash
    end
  end
end
