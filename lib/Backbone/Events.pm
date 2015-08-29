package Backbone::Events;

use Moo::Role;
use namespace::autoclean -also => qr/^_bbe_parse_events/;

# ABSTRACT: a port of the Backbone.js event API

=head1 SYNOPSIS

    package EventBus {
        use Moo;
        with 'Backbone::Events';
    };
    my $bus = EventBus->new;

    $bus->on('event:subtype', \&do_something);
    ...
    $bus->trigger('event:subtype', qw(args for callback))

=head1 METHODS

=head2 on

=head2 off

=head2 trigger

=head2 once

=head2 listen_to

=head2 stop_listening

=head2 listen_to_once

=head1 SEE ALSO

L<http://backbonejs.org/#Events>

=cut

has _bbe_events => (
    is      => 'ro',
    default => sub { {} },
);

has _bbe_listening_to => (
    is      => 'ro',
    default => sub { {} },
);

sub _bbe_trigger {
    my ($self, $event_ref, @args) = @_;
    my $cb = $event_ref->{cb};

    $cb->(@args);

    $self->off($event_ref->{event}, $cb) if $event_ref->{once};
}

sub _bbe_parse_events {
    my ($orig, $self, $events, @args) = @_;
    if (ref $events eq 'HASH') {
        $self->$orig($events->{$_}, @args) for keys %$events;
    } elsif ($events and $events =~ /\s+/) {
        my $result;
        $result = $self->$orig($_, @args) for split /\s+/, $events;
        # return last result
        return $result;
    } else {
        return $self->$orig($events, @args);
    }
}

sub _bbe_parse_events2 {
    my ($orig, $self, $other, $events, @args) = @_;
    if (ref $events eq 'HASH') {
        $self->$orig($other, $events->{$_}, @args) for keys %$events;
    } elsif ($events and $events =~ /\s+/) {
        my $result;
        $result = $self->$orig($other, $_, @args) for split /\s+/, $events;
        # return last result
        return $result;
    } else {
        return $self->$orig($other, $events, @args);
    }
}

around on => \&_bbe_parse_events;
sub on {
    my ($self, $event, $cb, %opts) = @_;
    $self->_bbe_events->{$event}{$cb} = {
        %opts,
        cb    => $cb,
        event => $event,
    };
    return $cb;
}

around off => \&_bbe_parse_events;
sub off {
    my ($self, $event, $cb) = @_;
    my @matches = keys %{$self->_bbe_events};
    # match event and any types under a namespace
    @matches = grep {/^\Q$event\E(:.*)?$/} @matches if $event;

    for my $match (@matches) {
        my $cbs = $self->_bbe_events->{$match};
        if (defined $cb) {
            delete $cbs->{$cb};
        } else {
            %$cbs = ();
        }
        # garbage collect empty hash refs
        delete $self->_bbe_events->{$match} unless %$cbs;
    }
}

around trigger => \&_bbe_parse_events;
sub trigger {
    my ($self, $event, @args) = @_;
    my $regex;
    if (my ($ns) = $event =~ /^(.*?):/) {
        # if $event is a $ns:$type, match $event and $ns
        $regex = qr/^(\Q$ns\E|\Q$event\E)$/;
    } else {
        $regex = qr/^\Q$event\E$/;
    }

    my @matches = grep {/$regex/} keys %{$self->_bbe_events};
    for my $match (@matches) {
        $self->_bbe_trigger($_, @args)
            for values %{$self->_bbe_events->{$match}//{}};
    }
    # call everything registered on 'all'
    $self->_bbe_trigger($_, $event, @args)
        for values %{$self->_bbe_events->{all}//{}};
}

around once => \&_bbe_parse_events;
sub once {
    my ($self, $event, $cb) = @_;
    $self->on($event, $cb, once => 1);
    return $cb;
}

around listen_to => \&_bbe_parse_events2;
sub listen_to {
    my ($self, $other, $event, $cb, %opts) = @_;

    $self->_bbe_listening_to->{$other}{$event}{$cb} = [
        $other,
        $cb,
    ];
    $other->on($event, $cb, %opts);

    return $cb;
}

around stop_listening => \&_bbe_parse_events2;
sub stop_listening { 
    my ($self, $other, $event, $cb) = @_;
    my $listening = $self->_bbe_listening_to;

    my @other_matches = defined $other ? ($other) : keys %$listening;
    for my $other_match (@other_matches) {
        my $events = $listening->{$other_match} // {};

        my @event_matches = keys %$events;
        # match event and any types under a namespace
        @event_matches = grep {/^\Q$event\E(:.*)?$/} @event_matches
            if defined $event;
        for my $event_match (@event_matches) {
            my $cbs = $events->{$event_match};

            for my $cb_match (defined $cb ? ($cb) : keys %$cbs) {
                my ($other_obj, $cb) = @{$cbs->{$cb_match}//[]};
                $other_obj->off($event_match, $cb_match);
                delete $cbs->{$cb_match};
            }

            # garbage collect empty hash refs
            delete $events->{$event_match} unless %$cbs;
        }

        # garbage collect empty hash refs
        delete $listening->{$other_match} unless %$events;
    }
}

around listen_to_once => \&_bbe_parse_events2;
sub listen_to_once {
    my ($self, $other, $event, $cb) = @_;
    $self->listen_to($other, $event, $cb, once => 1);
    return $cb;
}

1;
