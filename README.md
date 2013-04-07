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
Tasks:
  chaos bootstrap -s, --ssh=SSH     # Bootstrap a server
  chaos create -s, --server=SERVER  # Create an application on the server
  chaos help [TASK]                 # Describe available tasks or one specific task
  chaos update -s, --server=SERVER  # Update a server configuration running chef
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
