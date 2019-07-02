Sequel.migration do
  up do

    # Transfer.created_by should be the transfer_proposal.created_by 
    self[:transfer]
      .from(:transfer, :transfer_proposal)
      .where(Sequel[:transfer][:transfer_proposal_id] => Sequel[:transfer_proposal][:id])
      .update(Sequel[:transfer][:created_by] => Sequel[:transfer_proposal][:created_by])

  end
end
