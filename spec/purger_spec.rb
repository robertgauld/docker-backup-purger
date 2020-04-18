# frozen_string_literal: true

describe Purger do
  let(:default_initializer_options) do
    {
      glob: 'path/to/glob/*',
      all_from_last_days: 1,
      dailies: 1,
      weeklies: 1,
      monthlies: 1
    }
  end
  subject { described_class.new(**default_initializer_options) }

  describe 'Default configuration' do
    it 'File finding regexp' do
      expect(subject.send(:regexp)).to eq(/.*(?<when>\d{4}-\d{2}-\d{2}).*/)
    end

    it 'Date converting string' do
      expect(subject.send(:strptime)).to eq '%Y-%m-%d'
    end
  end

  describe '#run' do
    it 'Deletes items' do
      expect(subject).to receive(:get_items).and_return([described_class::Item.new('path/to/delete', Date.today, false)])
      expect(FileUtils).to receive(:rm_rf).with('path/to/delete')
      subject.run
    end

    it 'Keeps items' do
      expect(subject).to receive(:get_items).and_return([described_class::Item.new('path/to/keep', Date.today, true)])
      expect(FileUtils).not_to receive(:rm_rf)
      subject.run
    end
  end

  it '#dry_run' do
    items = [
      described_class::Item.new('path/to/delete', Date.today, false),
      described_class::Item.new('path/to/keep', Date.today, true)
    ]
    expect(subject).to receive(:get_items).and_return(items)

    expect(subject).to receive(:puts).with('Would keep:').ordered
    expect(subject).to receive(:puts).with("\tpath/to/keep").ordered
    expect(subject).to receive(:puts).with('Would delete:').ordered
    expect(subject).to receive(:puts).with("\tpath/to/delete").ordered

    subject.dry_run
  end

  context 'Private methods' do
    describe '#get_items' do
      it 'Returns array of items' do
        time = DateTime.new(2020, 4, 18)
        Timecop.freeze(time) do
          item = double described_class::Item
          allow(item).to receive(:date_time).and_return(time)
          expect(item).to receive(:keep=).with(true).at_least(:once)

          expect(Dir).to receive(:glob).with('path/to/glob/*')
                                       .and_return(['path/to/glob/2020-04-18.txt'])
          expect(described_class::Item).to receive(:new).with('path/to/glob/2020-04-18.txt', time, false)
                                                        .and_return(item)

          expect(subject.send(:get_items)).to match_array [item]
        end
      end

      it 'Ignore items where regex fails to match' do
        time = DateTime.new(2020, 4, 18)
        Timecop.freeze(time) do
          item = double described_class::Item
          allow(item).to receive(:date_time).and_return(time)
          expect(item).to receive(:keep=).with(true).at_least(:once)

          expect(Dir).to receive(:glob).with('path/to/glob/*')
                                       .and_return(['path/to/glob/nonsense.txt', 'path/to/glob/2020-04-18.txt'])
          expect(described_class::Item).to receive(:new).with('path/to/glob/2020-04-18.txt', time, false)
                                                        .and_return(item)

          expect(subject.send(:get_items)).to match_array [item]
        end
      end

      describe 'Uses initialized' do
        it 'glob' do
          subject = described_class.new(**default_initializer_options.merge(glob: 'use/this/glob/path/*'))
          expect(Dir).to receive(:glob).with('use/this/glob/path/*').and_return([])
          expect(subject.send(:get_items)).to match_array []
        end

        it 'regex' do
          regexp = double Regexp
          subject = described_class.new(**default_initializer_options.merge(regexp: regexp))

          expect(Dir).to receive(:glob).with('path/to/glob/*').and_return(['path/to/glob/file'])
          expect(regexp).to receive(:match).with('path/to/glob/file').and_return(nil)

          expect(subject.send(:get_items)).to match_array []
        end

        it 'strptime' do
          regexp = double Regexp
          subject = described_class.new(**default_initializer_options.merge(strptime: 'my-strptime', regexp: regexp))

          time = DateTime.new(2000, 1, 1)
          item = double described_class::Item
          allow(item).to receive(:date_time).and_return(time)

          expect(Dir).to receive(:glob).with('path/to/glob/*')
                                       .and_return(['path/to/glob/2000-01-01.txt'])
          expect(regexp).to receive(:match).with('path/to/glob/2000-01-01.txt')
                                           .and_return(when: 'when-from-regexp')
          expect(DateTime).to receive(:strptime).with('when-from-regexp', 'my-strptime')
                                                .and_return('parsed date_time')
          expect(described_class::Item).to receive(:new).with('path/to/glob/2000-01-01.txt', 'parsed date_time', false)
                                                        .and_return(item)

          expect(subject.send(:get_items)).to match_array [item]
        end
      end

      describe 'Marks items for keeping' do
        let(:default_initializer_options) do
          {
            glob: 'path/to/glob/*',
            all_from_last_days: 0,
            dailies: 0,
            weeklies: 0,
            monthlies: 0
          }
        end

        before :each do
          items = %w[
            path/to/glob/2020-04-15.txt
            path/to/glob/2020-04-10.txt
            path/to/glob/2020-04-05.txt
            path/to/glob/2020-03-30.txt
            path/to/glob/2020-03-20.txt
            path/to/glob/2020-03-10.txt
            path/to/glob/2020-02-20.txt
            path/to/glob/2020-02-10.txt
            path/to/glob/2020-01-30.txt
            path/to/glob/2020-01-20.txt
            path/to/glob/2020-01-10.txt
          ]
          expect(Dir).to receive(:glob).with('path/to/glob/*').and_return(items)
          Timecop.freeze(Date.new(2020, 4, 15))
        end

        after(:each) { Timecop.return }

        it 'Honors all_from_last_days' do
          subject = described_class.new(**default_initializer_options.merge(all_from_last_days: 10))
          expected = %w[path/to/glob/2020-04-15.txt path/to/glob/2020-04-10.txt path/to/glob/2020-04-05.txt]
          expect(subject.send(:get_items).select(&:keep).map(&:path)).to match_array expected
        end

        it 'Honors dailies' do
          subject = described_class.new(**default_initializer_options.merge(dailies: 5))
          expected = %w[path/to/glob/2020-04-15.txt path/to/glob/2020-04-10.txt]
          expect(subject.send(:get_items).select(&:keep).map(&:path)).to match_array expected
        end

        it 'Honors weeklies' do
          subject = described_class.new(**default_initializer_options.merge(weeklies: 2, monthlies: 0))
          expected = %w[path/to/glob/2020-04-05.txt path/to/glob/2020-04-15.txt path/to/glob/2020-04-10.txt]
          expect(subject.send(:get_items).select(&:keep).map(&:path)).to match_array expected
        end

        it 'Honors monthlies' do
          subject = described_class.new(**default_initializer_options.merge(monthlies: 2))
          expected = %w[path/to/glob/2020-04-05.txt path/to/glob/2020-03-10.txt path/to/glob/2020-02-20.txt]
          expect(subject.send(:get_items).select(&:keep).map(&:path)).to match_array expected
        end

        it 'Honors week_start_on' do
          subject = described_class.new(**default_initializer_options.merge(weeklies: 2, week_start_on: 5))
          expected = %w[path/to/glob/2020-04-10.txt path/to/glob/2020-04-05.txt]
          expect(subject.send(:get_items).select(&:keep).map(&:path)).to match_array expected
        end
      end
    end
  end
end
