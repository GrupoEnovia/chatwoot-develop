class AiAgent::MessageBuffer
  BUFFER_KEY = 'ai_agent:buffer:%<conversation_id>d'
  LOCK_KEY   = 'ai_agent:job_lock:%<conversation_id>d'

  def initialize(conversation_id, buffer_seconds)
    @conversation_id = conversation_id
    @buffer_seconds  = buffer_seconds
    @redis           = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
  end

  def push(content)
    @redis.rpush(buffer_key, content)
    @redis.expire(buffer_key, @buffer_seconds + 120)
  end

  def pop_all
    messages = @redis.lrange(buffer_key, 0, -1)
    @redis.del(buffer_key)
    messages
  end

  # Returns true only for the first message — caller should enqueue the job
  def acquire_lock
    acquired = @redis.set(lock_key, '1', nx: true, ex: @buffer_seconds + 60)
    acquired == true || acquired == 'OK'
  end

  def release_lock
    @redis.del(lock_key)
  end

  private

  def buffer_key
    format(BUFFER_KEY, conversation_id: @conversation_id)
  end

  def lock_key
    format(LOCK_KEY, conversation_id: @conversation_id)
  end
end
