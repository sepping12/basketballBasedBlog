require "test_helper"
require "minitest/mock"

class GuessANumberBetweenOneAndTenJobTest < ActiveJob::TestCase
  Job = GuessANumberBetweenOneAndTenJob

  # `rand` è casuale: lo si sostituisce (stub) con un valore fisso, così il test è deterministico.
  def esegui(numero, estratto)
    job = Job.new(numero)
    job.stub(:rand, estratto) { job.perform_now }
  end

  test "perform_later accoda il job nella coda default, con il suo argomento" do
    assert_enqueued_with(job: Job, args: [3], queue: "default") { Job.perform_later(3) }
  end

  test "se il numero coincide il job finisce senza errori e senza riprovare" do
    assert_no_enqueued_jobs { esegui(3, 3) }
  end

  test "retry_on: un numero sbagliato fa riaccodare il job (ritardato di 1 secondo)" do
    assert_enqueued_with(job: Job, args: [3]) { esegui(3, 5) }
    assert_equal 1, enqueued_jobs.size
    assert_in_delta 1, enqueued_jobs.first[:at] - Time.now.to_f, 0.5
  end

  test "retry_on: dopo 8 tentativi si arrende e l'eccezione esce dal job" do
    job = Job.new(3)
    job.stub(:rand, 5) do
      7.times { job.perform_now }                            # tentativi 1-7: ogni volta si riaccoda
      assert_equal 7, enqueued_jobs.size
      assert_raises(Job::GuessedWrongNumber) { job.perform_now }   # l'8° è l'ultimo: l'eccezione esce
    end
    assert_equal 7, enqueued_jobs.size
  end

  test "discard_on: un numero non valido scarta il job senza riprovare e senza errori" do
    [0, 11, "tre", nil, 2.5].each do |non_valido|
      assert_no_enqueued_jobs { assert_nothing_raised { Job.perform_now(non_valido) } }
    end
  end

  test "perform (chiamato direttamente, senza le regole del job) solleva ThatsNotFair" do
    assert_raises(Job::ThatsNotFair) { Job.new.perform(11) }
  end
end
