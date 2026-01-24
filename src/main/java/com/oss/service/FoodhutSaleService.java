// ...existing code...
  // In your backend service method (Java):
  public FoodhutSale addSale(Long variationId, int preparedQty, int remainingQty, User recordedBy) {
      // Fetch the latest prepared quantity for this variation for today
      int totalPreparedToday = saleRepo.sumPreparedQtyForVariationToday(variationId, LocalDate.now());
      if (remainingQty > totalPreparedToday) {
          throw new IllegalArgumentException("Remaining quantity cannot exceed total prepared quantity for today");
      }
      FoodhutItemVariation variation =
              variationRepo.findById(variationId).orElseThrow();
      FoodhutSale sale = new FoodhutSale(null, variation, preparedQty, remainingQty, LocalDateTime.now(), recordedBy);
      return saleRepo.save(sale);
  }
// ...existing code...

