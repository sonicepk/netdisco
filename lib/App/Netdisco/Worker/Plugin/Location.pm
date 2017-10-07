package App::Netdisco::Worker::Plugin::Location;

use Dancer ':syntax';
use App::Netdisco::Worker::Plugin;
use aliased 'App::Netdisco::Worker::Status';

use App::Netdisco::Transport::SNMP;

register_worker({ stage => 'check' }, sub {
  return Status->error('Missing device (-d).')
    unless defined shift->device;
  return Status->done('Location is able to run');
});

register_worker({ stage => 'main' }, sub {
  my ($job, $workerconf) = @_;
  my ($device, $data) = map {$job->$_} qw/device extra/;

  # snmp connect using rw community
  my $snmp = App::Netdisco::Transport::SNMP->writer_for($device)
    or return Status->defer("failed to connect to $device to update location");

  my $rv = $snmp->set_location($data);

  if (!defined $rv) {
    return Status->error(
      "failed to set location on $device: ". ($snmp->error || ''));
  }

  # confirm the set happened
  $snmp->clear_cache;
  my $new_data = ($snmp->location || '');
  if ($new_data ne $data) {
    return Status->error("verify of location failed on $device: $new_data");
  }

  # update netdisco DB
  $device->update({location => $data});

  return Status->done("Updated location on $device to [$data]");
});

true;