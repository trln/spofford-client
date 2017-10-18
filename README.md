# Spofford::Client

A command line utility for interacting with a Spofford server instance.

## Installation

Command line usage, assuming a working Ruby installation:
    
    $ git clone https://github.com/trln/spofford-client
    $ cd spofford-client
    $ bundle exec rake install 

Which will place the `spofford` script on your PATH (does this work on Windows? You can always install this on a Linux VM, and use directory sharing to process files on the host OS, if use the Linux subsystem if you're on Windows 10).

## Usage

The commands all have the form 

    $ spofford [command] [options] [file [file2, file3 ...]]

_Setup is required before first use_.  

### Configuration

Command: `config`
Sample:

     $ spofford config

This creates (or overwrites) a file named `.spofford-client.yml` in the current working directory, based on your responses to questions. 

This is an interactive process, where you will be asked for:

 * the base URL to the Spofford instance (default: `http://localhost:3000`, which corresponds to a Rails application running on your machine.) 
 * an output directory (default: `packages` -- a subdirectory in the current directory) -- this is where any `.zip` packages created during `ingest` or `package` operations will be placed.
 * an account name (email address); this corresponds to an account that you have already signed up for and had approved by an administrator on the Spofford instance.  The default value represents a guess based on your hostname.
 * You will be offered the opportunity to create an *authentication token* at this point (generally, you will want to do this on first setup).

## Authentication Tokens

To make it simple to submit ingest packages via automated tasks (e.g. `cron`), Spofford supports the use of *authentication tokens*; these are auto-generated passphrases that are stored within the configuration, and are used by the `ingest` command to authenticate.  This saves you from having to
store your account password on disk, instead using a renewable authentication token which is only valid for a limited range of operations. Should your authentication token become compromised, you can generate a new one.

Note that each account may only have one authentication token associated with it, and there is no way for a user to query for the current token.  You can generate a new one (using the `authenticate` command), but *this sets a new token for your account*; so any other configurations you have linked to the account will have to be updated.

## Commands

This section documents intent; if in doubt,

    $ spofford help commands

may contain different information; if so, that output should be considered definitive!

### `ingest`

The ingest command has the form

    $ spofford ingest [options] [files]

* If one filename is specified and has the `.zip` extension, it will be assumed to be a complete ingest package (see below).
* if multiple filenames are specified, or the first one does not have a `.zip` extension, then they will be assumed to specify the constituents of an ingest package.
* the `--json` option tells the client that only the first file matters, and it will be interpreted as an Argot JSON file with added/updated documents.

When used in the second form, the command will, in the default configuration, create a timestamped `zip` file in the configuration's `:output` directory.  Since we are not (currently) using manifests, the interpretation of each file depends on its filename (and extension).

See the `package` command for the details.

#### Ingest Options
|Option| Long Form | Meaning | Default / Notes |
|------|-----------|---------|-----------------|
|`-c`| `--config=FILE` | path to configuration file to be used | `.spofford-client.yml` |
| | `--json` | Don't create a package, submit the first file as an add/update Argot file| off |
|`-v`| `--verbose` | Be fairly chatty about what's happening while performing  |the ingest | off; you might want to specify this switch if you're experiencing problems |
| | `--debug` | Be extremely chatty about HTTP operations| off; use to help figure out what's going on if `-v` isn't telling you enough |
| \* `-a` | `--account=YOU@SOMEWHERE@EDU` | Override account name to use | empty; may be useful for testing? |
| \* `-u` | `--base_url=URL` | Override base URL | empty; maybe useful for testing? |

Options marked with a `\*` are experimental and may be removed.

### `package`

Allows creation of an ingest package from one or more files.

    $ spofford package [options] file1 [file2, [file3 ..]]

The `ingest` command uses the same packager under the hood, so the primary reason to use this command is for debugging, or you like to do things manually.

#### Package Options

| Option | Full | Meaning | Default / Notes |
|--------|------|---------|------------------|
|`-c`| `--config=FILE` | path to configuration file to be used | `.spofford-client.yml` |
|`-o`| `--output=FILE_OR_DIRECTORY` | Where to send output | value of the `:output` parameter in the active configuration.  If it is a filename ending in .zip, the file will be created or overwritten.  Otherwise, if it either is a directory (even one that doesn't exist yet), will be interpreted as a directory where `spofford-ingest-[timestamp].zip` will go.  If both of those fail, defaults to `spofford-ingest.zip` in the working directory. |
|`-v`| `--verbose` | Be fairly chatty about what's happening while performing the packaging | off; you might want to specify this switch if you're experiencing problems |
|-t | `--test` | Test package creation, but do not create output file; implies `--verbose` | off |

#### Ingest Package Format

An ingest package is a `.zip` file, containing:

  * zero or more files with the pattern `delete*.json`: these files are assumed to contain a JSON array containing the Unique IDs of records to be removed from the shared index.
  * zero or more Argot (JSON) files with the pattern `add*.json` containing records to be updated.

These are the only two filename formats Spofford (the server) understands and will process; you can insert other files into the ingest package, and they will be stored (at least temporarily), but will not otherwise be intepreted by Spofford.

In order to make it easier to create valid ingest packages, the packager provides some assistance in converting filenames supplied on the command line:

Files matching the pattern `delete*.json` and `add*.json` are ingested as-is, and assumed to be in the proper format.

Files starting with `delete` and having some other extension will be processed by the packager into JSON arrays, and stored in the ingest package with a `.json` extension after being converted to JSON arrays of document IDs using the following logic:

Extension `.csv` -- file is interpreted as a CSV, where each line contains comma-separated identifers of documents to be removed from the index.

ALl other extensions -- assumed to contain one unique identifier per line of a document to be removed from the index.

Finally, any file with `argot` in the name somwhere that also has a `.json`
extension will have `add-` prepended to their name before they are stored in the zip.

Note all these comparisons etc. are done against a filename stripped of path, and which have been converted to lower case.

### Ingest Package Examples

    $ spofford package foo.json /home/user/marc-to-argot/argot-7.json /ils/updates/delete

Contents (assuming all named files exist):
```
foo.json # ignored by spofford
add-argot-7.json # add/update file
delete.json # JSON array of the lines in /ils/updates/delete
```


### A Note on Validation

The packager is doing quite a few things, and may in the future add more quality checks, but for now it will let you do all sorts of things you may not actually want to do.  

You probably want to validate your Argot before you try to ingest or package it, using the tools provided by the `argot` gem.

### `authenticate`

Obtains a new authentication token from Spofford and writes it to the configuration file.  This must be used interactively, as you need to log in
with your account's password in order to generate the new token.
   
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trln/spofford-client.
