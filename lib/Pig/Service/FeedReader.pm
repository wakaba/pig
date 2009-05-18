package Pig::Service::FeedReader;
use strict;
use warnings; 

use Moose;
# TODO Pig::Service を Role にする

#use Pig::Service::FeedReader::Channel;
#use Pig::Service::FeedReader::Feed;
use URI;

has interval => (
    is => 'ro',
    default => sub {
        60 * 30; # 30分
    }
);

has bot_name => (
    is => 'rw',
    isa => 'Str',
    default => sub { 'feed' },
);

has channels => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { [] },
);

sub BUILDARGS {
    my $class = shift;

    my %args;
    if ( scalar(@_) eq 1 && ref $_[0] eq 'HASH') {
        %args = %{ $_[0] };
    }
    else {
        %args = @_;
    }

    my $channels = {};
    my $chs = delete $args{channels};
    for my $key (keys %$chs) {
        my $ch = $chs->{$key};
        my $feeds = [];
        for my $f (@{ $ch->{feeds} }) {
            push @$feeds, Pig::Service::FeedReader::Feed->new(uri => URI->new($f->{uri})); 
        }
        $channels->{$key} = Pig::Service::FeedReader::Channel->new(name => $key, feeds => $feeds);
    }
    $args{channels} = $channels;
    $class->SUPER::BUILDARGS(%args);
}

sub on_start { }

sub on_check {
    my ($self, $pig) = @_;

    for my $channel ( values %{ $self->channels } ) {
        next unless $channel->is_active;

        for my $feed (@{ $channel->feeds }) {
            $feed->each_new_entry( sub { 
                my $entry = shift;
                warn $entry->title;

                # TODO: メッセージフォーマットをconfigで指定できるよう
                my $message = sprintf("%s %s", ($entry->title || '[no title]'), ($entry->link || '[no url]'));
                $pig->privmsg( $self->bot_name, $channel->name, $message );
            });
        }
    }
}

sub on_ircd_join {
    my ($self, $pig, $nick, $channel) = @_;
    return if $nick eq $self->bot_name;
    return unless $self->channels->{$channel};

    $self->channels->{$channel}->activate;
    $pig->join($self->bot_name, $channel);
}

sub on_ircd_part {
    my ($self, $pig, $nick, $channel) = @_;
    return if $nick eq $self->bot_name;
    return unless $self->channels->{$channel};

    $self->channels->{$channel}->deactivate;
    $pig->part($self->bot_name, $channel);
}

__PACKAGE__->meta->make_immutable;
no Moose;

package Pig::Service::FeedReader::Channel;
use Moose;
use URI;
use DateTime;

has name => (
    is => 'ro',
    isa => 'Str'
);

has is_active => (
    is => 'rw',
    isa => 'Bool',
    default => sub { 0 },
);

has feeds => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] },
);

sub activate {
    my $self = shift;
    $self->is_active(1);
}

sub deactivate {
    my $self = shift;
    $self->is_active(0);
}


__PACKAGE__->meta->make_immutable;
no Moose;

package Pig::Service::FeedReader::Feed;
use Moose;
use XML::Feed;
use URI;
use DateTime;
use Time::HiRes qw(sleep);

has uri => (
    is => 'ro',
    isa => 'URI'
);

has last_update => (
    is => 'rw',
    isa => 'DateTime',
);

sub fix_last_update {
    my ($self, $user) = @_;
    $self->last_update(DateTime->now(time_zone => 'Asia/Tokyo'));
}

sub each_new_entry {
    my ($self, $code) = @_;

    # TODO If-Modifed-Since をみて抜けたりする
    my $xml_feed = XML::Feed->parse($self->uri);
    sleep 1; # 適度にまつ
    if (!$xml_feed) {
        warn "fetching feed is failed " . $self->uri;
        return;
    }
    
    my $has_new = 0;
    for my $entry (reverse($xml_feed->entries)) {
        use Data::Dumper;

        warn Dumper $entry->title; 
        #next if $self->last_update && $entry->issued < $self->last_update;
        $has_new = 1;
        $code->($entry);
    }
    $self->fix_last_update if $has_new;
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
