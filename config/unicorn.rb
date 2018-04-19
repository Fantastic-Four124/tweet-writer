worker_processes Integer(ENV['UNICORN_WORKERS'] || 4)
timeout 120
preload_app true


after_fork do |server, worker|
  $writer_client = WriterClient.new('writer_queue',ENV["RABBITMQ_BIGWIG_RX_URL"])
end

before_exec do |server|
  ENV['BUNDLE_GEMFILE'] = "#{apppath}/current/Gemfile"
end
