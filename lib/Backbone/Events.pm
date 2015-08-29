package Backbone::Events;

use Moo::Role;

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

sub on {
    my ($self, $event, $cb, %opts) = @_;
    $self->_bbe_events->{$event}{$cb} = {
        %opts,
        cb    => $cb,
        event => $event,
    };
    return $cb;
}

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

sub once {
    my ($self, $event, $cb) = @_;
    $self->on($event, $cb, once => 1);
    return $cb;
}

sub listen_to {
    my ($self, $other, $event, $cb, %opts) = @_;

    $self->_bbe_listening_to->{$other}{$event}{$cb} = [
        $other,
        $cb,
    ];
    $other->on($event, $cb, %opts);

    return $cb;
}

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

sub listen_to_once {
    my ($self, $other, $event, $cb) = @_;
    $self->listen_to($other, $event, $cb, once => 1);
    return $cb;
}

1;
