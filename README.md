# NAME

Backbone::Events - a port of the Backbone.js event API

# VERSION

version 0.0.1

# SYNOPSIS

    package MyEventBus {
        use Moo;
        with 'Backbone::Events';
    };
    my $bus = MyEventBus->new;

    $bus->on('event:subtype', \&do_something);
    ...
    $bus->trigger('event:subtype', qw(args for callback))

# METHODS

## on($event, $callback)

## off(\[$event\], \[$callback\])

## trigger($event, @args)

## once($event, $callback)

## listen\_to($other, $event, $callback)

## stop\_listening(\[$other\], \[$event\], \[$callback\])

## listen\_to\_once($other, $event, $callback)

# SEE ALSO

[http://backbonejs.org/#Events](http://backbonejs.org/#Events)

# AUTHOR

Mark Flickinger

# COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Mark Flickinger.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.
