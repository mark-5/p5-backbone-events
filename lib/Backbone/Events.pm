package Backbone::Events;

use Scalar::Util qw(weaken);
use Moo::Role;
use namespace::autoclean;

has _bbe_events => (
    is      => 'ro',
    default => sub { {} },
);

has _bbe_listening_to => (
    is      => 'ro',
    default => sub { {} },
);

sub on {
    my ($self, $event, $cb, %opts) = @_;
    my $id = $opts{alias} // $cb;
    $self->_bbe_events->{$event}{$id} = $cb;
    return $id;
}

sub off {
    my ($self, $event, $id) = @_;
    my @matches = keys %{$self->_bbe_events};
    # match event and any types under a namespace
    @matches    = grep {/^\Q$event\E(:.*)?$/} @matches if $event;

    for my $match (@matches) {
        my $ids = $self->_bbe_events->{$match};
        if (defined $id) {
            delete $ids->{$id};
        } else {
            %$ids = ();
        }
        # garbage collect empty hash refs
        delete $self->_bbe_events->{$match} unless %$ids;
    }
}

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
        $_->(@args) for values %{$self->_bbe_events->{$match}//{}};
    }
    # call everything registered on 'all'
    $_->($event, @args) for values %{$self->_bbe_events->{all}//{}};
}

sub once {
    my ($self, $event, $_cb) = @_;
    weaken($self);

    my $cb = sub {
        $self->off($event, $_cb);
        goto &$_cb;
    };
    $self->on($event, $cb, alias => $_cb);

    return $_cb;
}

sub listen_to {
    my ($self, $other, $event, $cb, %opts) = @_;
    my $id = $opts{alias} // $cb;

    $self->_bbe_listening_to->{$other}{$event}{$id} = [
        $other,
        $cb,
    ];
    $other->on($event, $cb, %opts);

    return $id;
}

sub stop_listening { 
    my ($self, $other, $event, $id) = @_;
    my $listening = $self->_bbe_listening_to;

    my @other_matches = defined $other ? ($other) : keys %$listening;
    for my $other_match (@other_matches) {
        my $events = $listening->{$other_match} // {};

        my @event_matches = keys %$events;
        # match event and any types under a namespace
        @event_matches    = grep {/^\Q$event\E(:.*)?$/} @event_matches
            if defined $event;
        for my $event_match (@event_matches) {
            my $ids = $events->{$event_match};

            for my $id_match (defined $id ? ($id) : keys %$ids) {
                my ($other_obj, $cb) = @{$ids->{$id_match}//[]};
                $other_obj->off($event_match, $id_match);
                delete $ids->{$id_match};
            }

            # garbage collect empty hash refs
            delete $events->{$event_match} unless %$ids;
        }

        # garbage collect empty hash refs
        delete $listening->{$other_match} unless %$events;
    }
}

sub listen_to_once {
    my ($self, $other, $event, $_cb) = @_;
    weaken($self);

    my $cb = sub {
        $self->stop_listening($other, $event, $_cb);
        goto &$_cb;
    };
    $self->listen_to($other, $event, $cb, alias => $_cb);

    return $_cb;
}

1;
