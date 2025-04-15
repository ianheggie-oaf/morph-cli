[![Gem Version](https://badge.fury.io/rb/morph-cli.png)](http://badge.fury.io/rb/morph-cli)

# Morph Commandline

Runs Morph scrapers from the commandline.

Actually it will run them on the Morph server identically to the real thing. That means not installing a bucket load of libraries
and bits and bobs that are already installed with the Morph scraper environments.

To run a scraper in your local directory

    morph

Yup, that's it.

It runs the code that's there right now. It doesn't need to be checked into git or anything.

For help

    morph help

## Installation

You'll need Ruby >= 1.9 and then

    gem install morph-cli

## Limitations

It uploads your (git) files everytime, excepting 

* directories: screenshots, tests (coverage, features, spec, test dirs), tmp and directories that start with '.' 
* `*.md` (docs) and `data.sqlite` (database).

So if it's big it might take a little while, and if its really too big it will be rejected!
Scrapers are not usually too big, so I'm hoping this won't really be an issue.

Note, if there is a `.git` directory it uses `git ls-files` to only upload significant files,
otherwise it relies on the exclusions listed above to keep the upload size reasonable.

Add the following to your `scraper.rb` just after the call to `Scraper.run`
if you want the data.sqlite database to be dumped to the log file when run by morph cli.
Morph-cli will save the dump to `tmp/data.sql`, remove `data.sqlite` and then run `sqlite3 data.sqlite < tmp/data.sql`
to recreate the database locally.

```ruby
  # Dump database for morph-cli
  if File.exist?("tmp/dump-data-sqlite")
    puts '-- dump of data.sqlite --'
    system "sqlite3 data.sqlite .dump"
    puts '-- end of dump --'
  end
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
