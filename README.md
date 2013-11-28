# Github book editor

The book editor is a javascript browser application that allows editing an
ebook in your browser and storing the ebook itself in a github repo.

More information can be found in the
[documentation](https://github.com/oerpub/documentation/) repository.

## Technologies used
* [Backbone.js](http://backbonejs.org/)
* [Marionette](http://marionettejs.com/)
* [Bootstrap](http://getbootstrap.com/)
* [Font Awesome](http://fontawesome.io/)
* [Jquery](http://www.jquery.com/)
* [Requirejs](http://requirejs.org/) and helpers such as
  [require-css](https://github.com/guybedford/require-css) and
  [require-less](https://github.com/guybedford/require-less)
* Phil Schatz's [Octokit.js](https://github.com/philschatz/octokit.js/)
* Our own [OERPub specific version of Aloha-Editor](https://github.com/oerpub/Aloha-Editor/)
* [NodeJS](http://nodejs.org/) and associated development tools such as npm
  and [Bower](https://github.com/bower/bower).

# Development and Building

Below are instructions for building the book editor yourself and a layout
of how the code is organized.

## Building

### With Vagrant
* Install [virtualbox](https://www.virtualbox.org/wiki/Downloads)
* Install [vagrant](http://downloads.vagrantup.com/)
* Clone [github book editor](https://github.com/oerpub/github-bookeditor) repo to somewhere
* Inside the repo run `vagrant up` from the command line
  * There is currently a bug in the build that makes it not run fully on the
    first pass, the workaround is to log into the vm after running `vagrant up`
    with `vagrant ssh`, then go into `/vagrant` and run `npm install`. That
    will finish the build for you.
* Vagrant will take a while to configure the new vm. When it's done you will be
  able to hit http://33.33.33.10/ in a web browser and see the editor.

### On Ubuntu Linux

This is tested on Ubuntu 12.04.

#### Installing node.js

First you need to install a copy of nodejs and the required utilities. Because
the version of nodejs that ships with your favourite linux distribution is
likely out of date, the easiest way is to install a basic development
environment and then compile nodejs from source.
    
    sudo apt-get update
    sudo apt-get install build-essential openssl libssl-dev pkg-config
    
Now download the source tarball and compile it:
    
    cd /tmp
    wget http://nodejs.org/dist/v0.10.22/node-v0.10.22.tar.gz
    tar zxf node-v0.10.22.tar.gz
    cd node-v0.10.22
    ./configure --prefix=$HOME/nodejs
    make && make install

For ease of use, I recommend that you add the npm bin directory to your PATH by
typing

    export PATH=$PATH:$HOME/nodejs/bin

You can also add this line to the end of `$HOME/.profile` so it gets added to
the PATH every time you open a shell session.

#### Installing coffeescript

Once you have node installed, you can use npm to install the rest of what you
need. You will need coffee script and lessc if you're going to hack on the
Aloha code.

    npm install -g coffee-script
    npm install -g lessc

#### Installing the book editor

Next clone the bookeditor repo. For this example we will clone it into your
home directory:

    cd $HOME
    git clone git@github.com:oerpub/github-bookeditor.git

Then use npm to install all dependencies:

    cd github-bookeditor
    npm install

#### Setting up a web server

* The simplest way to get going, is to install the node package called
   http-server:

       npm install -g http-server

   Then you can launch a web-server by typing:

       http-server

   The application itself can then be found at http://localhost:8080/


* Another option is to install apache and symlink your development directory
   into the default document root:

       sudo apt-get install apache2
       sudo ln -s $HOME/github-bookeditor /var/www/github-bookeditor

   The application can then be found at http://localhost/github-bookeditor/

## Developing on components in bower\_components.

The github bookeditor depends on several [several components](
https://github.com/oerpub/documentation/blob/gh-pages/README.md).
These components can be found in the `bower_components` directory. Some of
these are themselves checkouts from github, but unfortunately that are not
real clones, so direct development on these are not possible.

To develop these products, you need to remove the existing checkout, and
replace it with a clone. Because running `npm install` blows away any
changes you made in bower\_components, the suggested method is to clone it to
an alternate directory and use symlinks. It is much simpler to replace a
symlink than it is to re-clone a large product such as aloha-editor.

For example, if I want to develop on Aloha-Editor, I would link it
like this:

    cd bower_components
    git clone git@github.com:oerpub/Aloha-Editor.git aloha-editor-dev
    rm -rf aloha-editor && ln -s $HOME/aloha-editor-dev aloha-editor

This will create a symlink in bower\_components that point to a real checkout
in aloha-editor-dev, allowing you to do development in a familiar setting.

If your operating system doesn't support symlinks, you have no choice but to
name your git clone correctly. If you accidentally blow it away, you'd have to
repeat the above steps to clone it again.

To avoid blowing away your development clone in bower\_components, you can
edit `bower.json` and temporarily remove that item from the dependencies. Just
take care not to accidentally commit bower.json in this shape.

## Building Documentation

Documentation is built using `docco`.

    find . -name "*.coffee" | grep -v './bower_components/' | grep -v './node_modules' | xargs ./node_modules/docco/bin/docco

Check the `./docs` directory to read through the different modules.

## Code layout

Except for the technologies listed above, the book editor itself is made up
of three other products that each live in its own repository. The editor itself
started its life as [atc](https://github.com/Connexions/atc/), but was soon
used as the basis for the a github based [book editor](
https://github.com/oerpub/github-bookeditor/).

At the time of writing, [work is in progress
](https://github.com/oerpub/github-bookeditor/pull/115) to make atc
generic enough that github-book would consist of only a hand full of extensions
and replacements.

A further progression in this process would be to [split the common part from
atc](https://github.com/oerpub/github-bookeditor/pull/115#issuecomment-28458218)
so that atc and the bookeditor can each have their own customisations.

You should find all the relevant components in the `bower_components` directory
inside the github-bookeditor checkout.


### Directory Layout

TODO: Update this once the product is split.

* `scripts/collections/`   Backbone Collections
* `scripts/configs/`       App and 3rd party configs
* `scripts/controllers/`   Marionette Controllers
* `scripts/helpers/`       Miscellaneous helper functions
* `scripts/models/`        Backbone Models and Marionette Modules
* `scripts/nls/`           Internationalized strings
* `scripts/routers/`       Marionette Routers
* `scripts/views/`         Backbone and Marionette Views
* `scripts/views/layouts/` Marionette Layouts
* `scripts/app.coffee`     Marionette Application
* `scripts/config.coffee`  Requirejs Config
* `scripts/main.js`        Initial Requirejs Loader
* `scripts/session.coffee` Model of Session
* `styles/`                LESS and CSS Styling
* `templates/`             Handlebars Templates
* `templates/helpers/`     Handlebars Helpers
* `test/`                  Testable mock data and scripts
* `index.html`             App's HTML Page

License
-------

This software is subject to the provisions of the GNU Affero General Public License Version 3.0 (AGPL). See license.txt for details. 

Copyright
---------
Code contributed by Rice University employees and contractors is Copyright (c)
2013 Rice University.  Code contributed by contractors to the OERPUB project is
Copyright (c) 2013 Kathi Fletcher.

Funding
-------
Development by the OERPUB project was funded by the Shuttleworth Foundation,
through a fellowship and project funds granted to Kathi Fletcher.
