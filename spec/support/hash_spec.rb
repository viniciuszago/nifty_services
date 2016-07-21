require 'spec_helper'
RSpec.describe NiftyServices::BaseService, type: :service do
  describe '#symbolize_keys' do
    let(:symbols) do
      {
        'nhe' => 'bar',
        'buiir' => 'mor',
        lol: :hue,
        blo: {
          asd: 123
        }
      }
    end
    let(:sample_output) do
      {
        nhe: 'bar',
        buiir: 'mor',
        lol: :hue,
        blo: {
          asd: 123
        }
      }
    end

    it { expect(symbols.symbolize_keys).to eq(sample_output) }
  end
end
