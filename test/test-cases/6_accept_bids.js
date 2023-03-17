exports.testAcceptBid = async (accounts) => {
  let paymentToken;
  let erc721;
  let marketplaceInstance;

  before(async () => {
    paymentToken = await TestERC20.deployed();
    erc721 = await TestERC721.deployed();
    marketplaceInstance = await TheeNFTMarketplace.deployed();
  });

  it('Should accept bid', async () => {
    const highestBid = await marketplaceInstance.getTokenHighestBid(
      erc721.address,
      0
    );

    const tokenOwner = await erc721.ownerOf(highestBid.tokenId);

    await erc721.setApprovalForAll(marketplaceInstance.address, true, {
      from: tokenOwner,
    });

    const balanceBefore = await paymentToken.balanceOf(tokenOwner);

    const receipt = await marketplaceInstance.acceptBidForToken(
      erc721.address,
      0,
      highestBid.bidder,
      highestBid.value, // Should be 4ETH
      {
        from: tokenOwner,
      }
    );

    console.log('Accept bid gas', receipt.receipt.gasUsed);

    const acceptBidLog = receipt.logs.find(
      (log) => log.event === 'TokenBidAccepted'
    );

    console.log('serviceFee', web3.utils.fromWei(acceptBidLog.args.serviceFee));
    console.log('royaltyFee', web3.utils.fromWei(acceptBidLog.args.royaltyFee));

    assert.equal(
      web3.utils.fromWei(acceptBidLog.args.bid.value),
      web3.utils.fromWei(highestBid.value)
    );

    const balanceAfter = await paymentToken.balanceOf(tokenOwner);

    console.log('balanceBefore', web3.utils.fromWei(balanceBefore));
    console.log('balanceAfter', web3.utils.fromWei(balanceAfter));
  });
};

// After: Listings
// 2-4 => 1ETH => account3-5

// After: Bids
// 0 => 2ETH => account3
//
//
// 1 => 1ETH => account6
// 2 => 1ETH => account6
// 3 => 1ETH => account6
