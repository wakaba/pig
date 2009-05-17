package Pig::Service::MyHatena;
use strict;
use warnings; 

use XML::Feed;
use URI;
use DateTime;
use Time::HiRes qw(sleep);

use Moose;
# TODO Pig::Service を Role にする

has interval => (
    is => 'ro',
    default => sub {
        60 * 30; # 30分
    }
);

has last_updates => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
);

has hatena_users => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { +{} },
);

sub fix_last_update_for {
    my ($self, $user) = @_;
    $self->last_updates->{$user} = DateTime->now(time_zone => 'Asia/Tokyo');
}

sub on_check {
    my ($self, $pig) = @_;

    use Data::Dumper;
    warn Dumper [keys %{ $self->hatena_users }];

    for my $hatena_user (keys %{ $self->hatena_users }) {
        # TODO If-Modifed-Since をみて抜けたりする
        my $feed = XML::Feed->parse(URI->new(sprintf('http://www.hatena.ne.jp/%s/activities.rss', $hatena_user)));
        sleep 1; # 適度にまつ

        if (!$feed) {
            warn "$hatena_user fetching rss is failed";
            next;
        }
        if (   $feed->entries 
            && (reverse($feed->entries))[0]->issued < $self->last_updates->{$hatena_user}) {
            warn "$hatena_user: not updated";
            next;
        }
        
        my $has_new = 0;
        for my $entry (reverse($feed->entries)) {
            $has_new = 1;
            # TODO: メッセージフォーマットをconfigで指定できるよう
            my $message = sprintf("%s (%s)", $entry->title, $entry->link);
            $pig->privmsg( $hatena_user, "#$hatena_user", $message );
        }
        $self->fix_last_update_for($hatena_user) if $has_new;
    }
}

sub on_ircd_join {
    my ($self, $pig, $nick, $channel) = @_;
    my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
    return if $self->hatena_users->{$nick};

    $pig->join($hatena_user, "#$hatena_user");
    $self->hatena_users->{$hatena_user} = 1;
}

sub on_ircd_part {
    my ($self, $pig, $nick, $channel) = @_;
    my ($hatena_user) = $channel =~ m/^\#(.*)$/xms;
    return if $self->hatena_users->{$nick};

    $pig->part($hatena_user, "#$hatena_user");
    delete $self->hatena_users->{$hatena_user};
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;