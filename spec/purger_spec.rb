require_relative 'spec_helper'

describe "Purger" do

  before :each do
    ARGV.clear
  end

  it "Initializes" do
    purger = Purger.new
    expect( purger ).not_to eq(nil)
  end

  it "Default configuration" do
    purger = Purger.new
    expect( purger.dailies ).to eq 7
    expect( purger.weeklies ).to eq 5
    expect( purger.monthlies ).to eq 6
    expect( purger.all_from_last_days ).to eq 7
    expect( purger.debug ).to be false
    expect( purger.dry_run ).to be false
    expect( purger.weekly_on ).to eq 1
  end

  describe "Run" do
    before :each do
      Timecop.freeze(Time.new(2016, 7, 1, 6, 30))
      @entries = ['.', '..', 'ignore_this_file', '20161231-0000']
      allow(File).to receive('directory?').and_return( true )
      @purger = Purger.new
      @purger.all_from_last_days = -1
      @purger.dailies = -1
      @purger.weeklies = -1
      @purger.monthlies = -1
    end
    after :each do
      Timecop.return
    end

    it "Honors all_from_last_days" do
      @entries += ['20160701-0200', '20160630-0800', '20160630-1234', '20160629-0200', '20160629-2359']
      expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
      @purger.all_from_last_days = 1
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-0200')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-2359')
      @purger.run('/media/target')
    end

    it "Honors dailies" do
      @entries += ['20160701-0100', '20160701-2300', '20160630-0100', '20160629-0100']
      expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
      @purger.dailies = 2
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0100')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160629-0100')
      @purger.run('/media/target')
    end

    it "Honors weeklies" do
      @entries += ['20160701-0100', '20160627-0100', '20160626-0100', '20160620-0100', '20160614-0900']
      expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
      @purger.weeklies = 2
      @purger.weekly_on = 1
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0100')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160626-0100')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160614-0900')
      @purger.run('/media/target')
    end

    it "Honors weekly_on" do
      @entries += ['20160701-0100', '20160623-0100', '20160624-0100', '20160617-0100']
      expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
      @purger.weeklies = 1
      @purger.weekly_on = 5
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160623-0100')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160617-0100')
      @purger.run('/media/target')
    end

    it "Honors monthlies" do
      @entries += ['20160701-0900', '20160701-0100', '20160615-0100', '20160510-1000', '20160412-0900']
      expect(Dir).to receive(:entries).with('/media/target').and_return( @entries )
      @purger.monthlies = 2
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160701-0900')
      expect(FileUtils).to receive(:rm_rf).with('/media/target/20160412-0900')
      @purger.run('/media/target')
    end

  end # describe Run

end
