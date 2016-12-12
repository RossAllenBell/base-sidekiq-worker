# base_sidekiq_worker
Sidekiq worker boilerplate I end up reimplementing on every background processing project I work on.

Jobs should implement BaseSidekiqWorker#perform. Uncomment the GC line if you're having memory issues you don't want to debug. Use blocked_by and runs_every as needed.

The static methods accessing Sidekiq's API are _not_ anything-safe.
