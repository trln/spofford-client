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

### `ingest`

The ingest command has the form

    $ spofford ingest [options] [files]

If one filename is specified and has the `.zip` extension, it will be assumed to be a complete ingest package; if multiple filenames are specified, or the first one does not have a `.zip` extension, then they will be assumed to specify the constituents of an ingest package.

When used in the second form, the command will create a timestamped `zip` file in the configured output directory containing the files named on the command line.  *_Spofford will try to guess each file's contents based on its name and extension_*.  See the `package` command for the details.

#### Ingest options
|Option| Long Form | Meaning | Default
|`-c`| `--config=FILE` | path to configuration file to be used | `.spofford-client.yml`
| | `--json` | Don't create a package, submit the first file as an add/update Argot file| off
|`-v`| `--verbose` | Be fairly chatty about what's happening while performing the ingest | off; you might want to specify this switch if you're experiencing problems
| | `--debug` | Be extremely chatty about HTTP operations| off; use to help figure out what's going on if `-v` isn't telling you enough
| \* `-a` | `--account=YOU@SOMEWHERE@EDU` | Override account name to use | empty; may be useful for testing?
| \* `-u` | `--base_url=URL` | Override base URL | empty; maybe useful for testing?

Options marked with a `\*` are experimental and may be removed.

    $ spofford help commands

May contain different information; if so, that output is definitive!


### `package`

Allows creation of an ingest package from one or more files.

    $ spofford package [options] file1 [file2, [file3 ..]]

The `ingest` command uses the same packager under the hood, so the primary reason to use this command is for debugging, or you like to do things manually.  
#### Ingest Package Format

An ingest package is a `.zip` file, containing:

  * zero or more files with the pattern `delete*.json`: these files are assumed to contain a JSON array containing the Unique IDs of records to be removed from the shared index.
  * zero or more Argot (JSON) files with the pattern `add*.json` containing records to be updated.

Empty `.zip`s will not be submitted.

The `package` command 

Outputs a `.zip` file, which by default is `spofford-ingest.zip` in the current working directory.
Files matching the pattern `delete*.json` will be ingested as-is, and will be assumed to contain JSON arrays of unique identifiers to be deleted (removed from the index).

Files matching the pattern `delete*.txt` (or any other extension that is not JSON) will be assumed to contain one unique identifier per line of a document to be removed from the index.  These will be automatically converted to a JSON array form file (which is the only one Spofford natively understands) before being included in the ingest package.

All other files matching the pattern `add*.json` extension will be assumed to contain Argot JSON for records that are to be added or updated in the index.  This is the filename pattern Spofford looks for to process additions/updates.

Note that, for purposes of matching and inclusion within the ingest package, filenames will be stripped of their paths and converted to lower case first.  That is, if you submit a file named `/path/to/argot/files/Add-UNC-2017-10-23.json`, it will show up in the ingest package as
'add-unc-2017-10-23.json'.

Filenames within an ingest package should be unique, or you'll get weird results.

It is possible to store other files in an ingest package; this is to support possible future expansion (e.g manifests, special processing directives, etc.), but for now this facility serves at best to allow you to supply notes to yourself.

When using the second form, the filenames can be specified in any order.

The packaging process will only include files that exist, and if the resulting
`.zip` would be empty, the ingest process will fail.


Thus, the only way to delete (de-index) a record is to use the `.zip` form.

The `ingest` package allows the creation of zip packages on the fly, and you can experiment with package creation using the `package` command.  There is also a `verify` command that will check the contents of a named .zip file to determine whether it is in the right form to be submitted to spofford.


#### `package` options

|Option| Long Form | Meaning | Default
|`-o`|`--output=DIRECTORY_OR_ZIP_FILE`| where to send the output; assumed to name a directory unless it ends in `.zip` | `./spofford-ingest.zip`
|`-t`|`--test`|Do not create the output file, just outline what would be done | off

### `authenticate`

Obtains a new authentication token from Spofford and writes it to the configuration file.  This must be used interactively, as you need to log in
with your account's password in order to generate the new token.

### Multiple Configurations

If you are responsible for multiple ingest profiles (e.g. one for your general collection and others for shared collections, etc.), you can follow one of two strategies:

* per-directory profile: each ingest profile has its own directory and configuration file.
* multiple profiles in the same directory: every command that uses a profile ((including `configure`) supports the `-c` parameter, that points to the configuration file to be used.

The former is reccomended, but the latter is supported to allow you to store all of your various configurations in a single (PRIVATE, please!  profiles can contain account information) source code repository.

   
## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/trln/spofford-client.
