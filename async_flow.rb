module AsyncFlow
  def initialize(payload = {}, meta = nil)
    @payload = payload
    @meta = meta || { 'return_values' => {}, 'flow_class' => self.class.name}
  end

  def await(object)
    AsyncCacher.new(object, self)
  end
  alias_method :a, :await

  def cached_return_value(object, method_name, arguments)
    val = @meta.fetch('return_values', {}).
      fetch(serialize(object), {}).
      fetch(serialize(method_name), {}).
      fetch(serialize(arguments), :no_cached_value)
    deserialize(val)
  end

  def cache_return_value(object, method_name, arguments, return_value)
    object = serialize(object)
    method_name = serialize(method_name)
    arguments = serialize(arguments)
    return_value = serialize(return_value)
    @meta['return_values'][object] = { method_name => { arguments => return_value } }
  end

  def serialize(ob)
    Marshal.dump(ob)
  end

  def deserialize(val)
    return val if val == :no_cached_value
    Marshal.load(val)
  end

  def step
    AsyncFlowJob.perform_async(@services, pos + 1, data)
  end

  def call(data)
    @data = data
    implementation(@data)
  rescue AsyncContinuation
    AsyncFlowJob.perform_async(@data, @meta)
  end
end

class AsyncCacher
  def initialize(object, flow)
    @object = object
    @flow = flow
  end

  def method_missing(method_name, *args)
    cached_return_value = @flow.cached_return_value(@object, method_name, args)
    if cached_return_value == :no_cached_value
      return_value = @object.public_send(method_name, *args)
      @flow.cache_return_value(
        @object,
        method_name,
        args,
        return_value
      )
      raise AsyncContinuation
    else
      cached_return_value
    end
  end

  def respond_to_missing?(method_name)
    @object.respond_to?(method_name) || super
  end
end

class AsyncFlowJob
  def perform(data, meta)
    flow_class = meta['flow_class']
    self.class.const_get(flow_class).new(data, meta).call(data)
  end

  def self.perform_async(data, meta)
    self.new.perform(data, meta)
  end
end

class AsyncContinuation < StandardError; end
