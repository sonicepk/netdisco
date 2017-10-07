package App::Netdisco::Worker::Plugin::Test;

use Dancer ':syntax';
use App::Netdisco::Worker::Plugin;
use aliased 'App::Netdisco::Worker::Status';

register_worker({ stage => 'main' }, sub {
  my ($job, $workerconf) = @_;
  return Status->done('Test (main) ran successfully (1).');
});

register_worker({ stage => 'check' }, sub {
  my ($job, $workerconf) = @_;
  return Status->done('Test (check) ran successfully.');
});

register_worker({ stage => 'early' }, sub {
  my ($job, $workerconf) = @_;
  return Status->error('Test (early) ran successfully.');
});

register_worker(sub {
  my ($job, $workerconf) = @_;
  return Status->noop('Test (undefined) ran successfully.');
});

true;