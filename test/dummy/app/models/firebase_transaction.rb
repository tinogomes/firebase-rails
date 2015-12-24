class FirebaseTransaction < FirebaseBase
  belongs_to :stock
  attr_accessor :buy, :sell
end
