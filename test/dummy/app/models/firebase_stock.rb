class FirebaseStock < FirebaseBase
  has_many :transactions
  attr_accessor :symbol, :price
end
