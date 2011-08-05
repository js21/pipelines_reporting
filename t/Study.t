#!/usr/bin/env perl
use strict;
use warnings;

BEGIN { unshift(@INC, './modules') }
BEGIN {
    use Test::Most tests => 19;
    use DBICx::TestDatabase;
    use PipelinesReporting::Schema;
    use_ok('PipelinesReporting::Study');
}

# setup test databases with seed data
my $dbh = DBICx::TestDatabase->new('PipelinesReporting::Schema');
$dbh->resultset('UserStudies')->create({ row_id => 1, sequencescape_study_id => 2, username => 'aaa'});
$dbh->resultset('UserStudies')->create({ row_id => 2, sequencescape_study_id => 2, username => 'bbb'});

$dbh->resultset('Project'    )->create({ row_id => 1, project_id => 1, ssid => 2 , name => 'Study Name'});
$dbh->resultset('Project'    )->create({ row_id => 2, project_id => 2, ssid => 10, name => 'Study Name'});

$dbh->resultset('Sample'     )->create({ row_id => 1, sample_id  => 3, project_id => 1 });

$dbh->resultset('Library'    )->create({ row_id => 1, library_id => 4, sample_id  => 3 });
$dbh->resultset('Library'    )->create({ row_id => 2, library_id => 7, sample_id  => 3 });

$dbh->resultset('Lane'       )->create({ row_id => 1, lane_id => 5, library_id => 4, processed => 7 });
$dbh->resultset('Lane'       )->create({ row_id => 2, lane_id => 6, library_id => 4, processed => 3 });
$dbh->resultset('Lane'       )->create({ row_id => 3, lane_id => 8, library_id => 7, processed => 3 });


# valid study
ok my $study = PipelinesReporting::Study->new(  
  _pipeline_dbh => $dbh,
  _qc_dbh => $dbh,
  sequencescape_study_id => 2,
  qc_grind_url => 'http://example.com',
  database_name => 'test',
  email_from_address => 'example@example.com',
  email_domain => 'example.com'
), 'initialise';


my @user_emails = ('aaa@example.com','bbb@example.com');
is_deeply $study->user_emails, \@user_emails, 'user emails';

my @qc_lane_ids  = (6,8);
is_deeply $study->qc_lane_ids, \@qc_lane_ids, 'qc lane ids';

my @mapped_lane_ids = (5);
is_deeply $study->mapped_lane_ids, \@mapped_lane_ids, 'mapped lane ids';

# check body of constructed email
my $expected_email_body = 'The following lanes have finished QC in Study Study Name.

http://example.com?mode=0&lane_id=6&db=test
http://example.com?mode=0&lane_id=8&db=test

';

is $study->_construct_email_body_for_lane_action('QC', $study->qc_lane_ids), $expected_email_body, 'QC email body';


$expected_email_body = 'The following lanes have finished Mapping in Study Study Name.

http://example.com?mode=0&lane_id=5&db=test

';
is $study->_construct_email_body_for_lane_action('Mapping', $study->mapped_lane_ids), $expected_email_body, 'Mapping email body';





## error cases
my @empty_array = ();
ok $study = PipelinesReporting::Study->new(  
  _pipeline_dbh => $dbh,
  _qc_dbh => $dbh,
  sequencescape_study_id => 99999,
  qc_grind_url => 'http://example.com',
  database_name => 'test',
  email_from_address => 'example@example.com',
  email_domain => 'example.com'
), 'initialise invalid study';
is_deeply $study->user_emails, \@empty_array , 'user emails invalid study';
is_deeply $study->qc_lane_ids, \@empty_array, 'qc lane ids undef if invalid study';
is_deeply $study->mapped_lane_ids, \@empty_array, 'mapped lane ids undef if invalid study';

ok $study = PipelinesReporting::Study->new(  
  _pipeline_dbh => $dbh,
  _qc_dbh => $dbh,
  sequencescape_study_id => 10,
  qc_grind_url => 'http://example.com',
  database_name => 'test',
  email_from_address => 'example@example.com',
  email_domain => 'example.com'
), 'initialise study with no users';
is_deeply $study->user_emails, \@empty_array, 'user emails empty';
is_deeply $study->qc_lane_ids, \@empty_array, 'qc lane ids undef if no users';
is_deeply $study->mapped_lane_ids, \@empty_array, 'mapped lane ids undef if no users';

# add a user for the study and lane ids should be empty
$dbh->resultset('UserStudies')->create({ row_id => 3, sequencescape_study_id => 10, username => 'aaa'});
ok $study = PipelinesReporting::Study->new(  
  _pipeline_dbh => $dbh,
  _qc_dbh => $dbh,
  sequencescape_study_id => 10,
  qc_grind_url => 'http://example.com',
  database_name => 'test',
  email_from_address => 'example@example.com',
  email_domain => 'example.com'
), 'initialise study with no users';
@user_emails = ('aaa@example.com');
is_deeply $study->user_emails, \@user_emails, 'user emails has 1 user';
is_deeply $study->qc_lane_ids, \@empty_array, 'qc lane ids empty if no lanes';
is_deeply $study->mapped_lane_ids, \@empty_array, 'mapped lane ids empty if no lanes';