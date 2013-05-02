# Chaos

Bootstrap and configure services on individual server. 
Can also configure your app to deploy to your freshly bootstrapped server using git.

## Installation

```bash
gem build chaos.gemspec
gem install chaos-X.X.X.gem
```

## Usage

```
Commands:
  chaos addons          # Manage app addons
  chaos app             # Manage app deployment configuration
  chaos config          # Manage app config vars
  chaos domains         # Manage app domains
  chaos help [COMMAND]  # Describe available commands or one specific command
  chaos server          # Manage server configuration
  chaos servicepacks    # Manage services offering addons on servers
```

## Links (Chaos components)

* [Hermes HTTP routes manager for Nginx](https://github.com/garnieretienne/chaos_hermes)
* [PostgreSQL Servicepack](https://github.com/garnieretienne/chaos-servicepack-postgresql)
* [Redis Servicepack](https://github.com/garnieretienne/chaos-servicepack-redis)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
