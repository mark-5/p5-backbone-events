package Backbone::Events;

use Carp qw(confess);
use List::MoreUtils qw(none);
use Scalar::Util qw(blessed);
use Moo::Role;
use namespace::autoclean -also => qr/^__bbe_/;

# ABSTRACT: a port of the Backbone.js event API

=head1 SYNOPSIS

    package MyEventBus {
        use Moo;
        with 'Backbone::Events';
    };
    my $bus = MyEventBus->new;

    $bus->on('event:subtype', \&do_something);
    ...
    $bus->trigger('event:subtype', qw(args for callback))

=head1 METHODS

=head2 on($event, $callback)

=head2 off([$event], [$callback])

=head2 trigger($event, @args)

=head2 once($event, $callback)

=head2 listen_to($other, $event, $callback)

=head2 stop_listening([$other], [$event], [$callback])

=head2 listen_to_once($other, $event, $callback)

=head1 SEE ALSO

L<http://backbonejs.org/#Events>

=cut

has _bbe_events => (
    is      => 'ro',
    default => sub { {} },
);

has _bbe_id => (
    is      => 'ro',
    default => sub { __bbe_new_id() },
);

has _bbe_listening_to => (
    is      => 'ro',
    default => sub { {} },
);

our $__bbe_last_id;
sub __bbe_new_id { ++$__bbe_last_id }

sub _bbe_trigger {
    my ($self, $event_ref, $event, @args) = @_;
    my $cb = $event_ref->{cb};

    if ($event_ref->{ns} eq 'all') {
        $cb->($event, @args);
    } else {
        $cb->(@args);
    }

    if ($event_ref->{once}) {
        my ($event, $listen_id) = @{$event_ref}{qw(event listen_id)};
        $self->off($event, $cb, listen_id => $listen_id//'');
    }
}

sub __bbe_wrap_multiple_events {
    my ($orig, $self, $events, @args) = @_;
    if (ref $events eq 'HASH') {
        $self->$orig($_, $events->{$_}, @args) for keys %$events;
    } elsif ($events and $events =~ /\s+/) {
        my $result;
        $result = $self->$orig($_, @args) for split /\s+/, $events;
        # return last result
        return $result;
    } else {
        return $self->$orig($events, @args);
    }
}

sub ___bbe_wrap_multiple_events2 {
    my ($orig, $self, $other, $events, @args) = @_;
    if (ref $events eq 'HASH') {
        $self->$orig($other, $_, $events->{$_}, @args) for keys %$events;
    } elsif ($events and $events =~ /\s+/) {
        my $result;
        $result = $self->$orig($other, $_, @args) for split /\s+/, $events;
        # return last result
        return $result;
    } else {
        return $self->$orig($other, $events, @args);
    }
}

sub __bbe_parse_ns {
    my ($event) = @_;
    my ($ns, $type) = split(':', $event//'', 2);
    return ($ns//'', $type//'');
}

sub __bbe_query {
    my ($ids, $q) = @_;
    return grep {
        my $id    = $_;
        my $match = 1;
        for my $field (keys %$q) {
            my $have = $ids->{$id}{$field} // '';
            my $want = $q->{$field};

            my $type = ref $want;
            if ($type eq 'ARRAY') {
                if (none {$_ eq $have} @$want) {
                    $match = 0;
                    last;
                }
            } else {
                if ($want ne $have) {
                    $match = 0;
                    last;
                }
            }
        }
        $match;
    } keys %$ids;
}

sub __bbe_does_events {
    my ($obj) = @_;
    return $obj
        && blessed($obj)
        && $obj->DOES(__PACKAGE__);
}

around on => \&__bbe_wrap_multiple_events;
sub on {
    my ($self, $event, $cb, %opts) = @_;
    my ($ns, $type) = __bbe_parse_ns($event);
    $self->_bbe_events->{__bbe_new_id()} = {
        %opts,
        cb   => $cb,
        ns   => $ns,
        type => $type,
    };
    return $cb;
}

around off => \&__bbe_wrap_multiple_events;
sub off {
    my ($self, $event, $cb, %opts) = @_;
    my ($ns, $type) = __bbe_parse_ns($event);

    my @ids = __bbe_query($self->_bbe_events, {
        %opts,
        ( cb        => $cb   )x!! $cb,
        ( ns        => $ns   )x!! $ns,
        ( type      => $type )x!! $type,
    });
    delete @{$self->_bbe_events}{@ids};
}

around trigger => \&__bbe_wrap_multiple_events;
sub trigger {
    my ($self, $event, @args) = @_;
    my ($ns, $type) = __bbe_parse_ns($event);

    my @ids = __bbe_query($self->_bbe_events, {
        ns   => [ 'all', $ns                 ],
        type => [ $type ? ($type, '') : ('') ],
    });

    for my $id (@ids) {
        my $event_ref = $self->_bbe_events->{$id};
        $self->_bbe_trigger($event_ref, $event, @args);
    }
}

around once => \&__bbe_wrap_multiple_events;
sub once {
    my ($self, $event, $cb) = @_;
    $self->on($event, $cb, once => 1);
    return $cb;
}

around listen_to => \&___bbe_wrap_multiple_events2;
sub listen_to {
    my ($self, $other, $event, $cb, %opts) = @_;
    confess "Cannot call listen_to on object that does not consume Backbone::Events"
        if $other and not __bbe_does_events($other);

    my ($ns, $type) = __bbe_parse_ns($event);
    $self->_bbe_listening_to->{__bbe_new_id()} = {
        %opts,
        cb       => $cb,
        event    => $event,
        ns       => $ns,
        other    => $other,
        other_id => $other->_bbe_id,
        type     => $type,
    };
    $other->on($event, $cb, %opts, listen_id => $self->_bbe_id);

    return $cb;
}

around stop_listening => \&___bbe_wrap_multiple_events2;
sub stop_listening {
    my ($self, $other, $event, $cb) = @_;
    my ($ns, $type) = __bbe_parse_ns($event);
    confess "Cannot call stop_listening on object that does not consume Backbone::Events"
        if $other and not __bbe_does_events($other);

    my $query = {
        ( cb   => $cb   )x!! $cb,
        ( ns   => $ns   )x!! $ns,
        ( type => $type )x!! $type,
    };
    $query->{other_id} = $other->_bbe_id if $other;
    my @ids = __bbe_query($self->_bbe_listening_to, $query);

    for my $id (@ids) {
        my $listen_ref = $self->_bbe_listening_to->{$id};
        my $other_obj  = $listen_ref->{other};
        my @args       = @{$listen_ref}{qw(event cb)};
        $other_obj->off(@args, listen_id => $self->_bbe_id);
    }
    delete @{$self->_bbe_listening_to}{@ids};
}

around listen_to_once => \&___bbe_wrap_multiple_events2;
sub listen_to_once {
    my ($self, $other, $event, $cb) = @_;
    $self->listen_to($other, $event, $cb, once => 1);
    return $cb;
}

1;
