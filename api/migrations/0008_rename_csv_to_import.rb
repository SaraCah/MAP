Sequel.migration do
  up do
    self.transaction do
      self[:transfer_file].filter(:role => 'CSV').update(:role => 'IMPORT')
    end
  end
end
