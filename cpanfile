requires 'namespace::autoclean', '0.16';
requires 'perl', 'v5.10.1';
requires 'Carp';
requires 'List::MoreUtils';
requires 'Moo::Role';
requires 'Scalar::Util';

on develop => sub {
    requires 'Dist::Zilla::Plugin::ExtraTests';
    requires 'Dist::Zilla::Plugin::Prereqs::FromCPANfile';
    requires 'Dist::Zilla::Plugin::ReadmeFromPod';
    requires 'Dist::Zilla::PluginBundle::Basic';
    requires 'Pod::Markdown';
    requires 'Test::Pod';
};

on test => sub {
    requires 'parent';
    requires 'Exporter';
    requires 'FindBin::libs';
    requires 'Moo';
    requires 'Test::LeakTrace';
    requires 'Test::More';
    requires 'Test::Strict';
};
