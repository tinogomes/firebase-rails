require 'test_helper'

class FirebaseBaseTest < ActiveSupport::TestCase
  def setup
    FirebaseStock.destroy_all
    FirebaseTransaction.destroy_all
  end

  def test_config_file
    assert_equal "rails-tests", ENV['FIREBASE_NAME']
  end

  def test_to_create_a_stock_object
    stock = FirebaseStock.create({symbol: "APPL"})
    assert_equal "APPL", stock.symbol
  end

  def test_to_find_single_stock_object_by_id
    stock = FirebaseStock.create({symbol: "APPL"})
    found_stock = FirebaseStock.find(stock.id)
    assert_equal stock.id, found_stock.id
  end

  def test_getting_all_stocks
    3.times do |num|
      FirebaseStock.create({symbol: num})
    end
    stocks = FirebaseStock.all
    assert_equal 3, stocks.count
  end

  def test_find_by_param
    stock_1 = FirebaseStock.create({symbol: "AAA"})
    stock_2 = FirebaseStock.create({symbol: "BBB"})
    found_stocks = FirebaseStock.find_by({symbol: "BBB"})
    assert_equal 1, found_stocks.count
    assert_equal stock_2.id, found_stocks.first.id
  end

  def test_find_by_boolean_param
    stock_1 = FirebaseTransaction.create({open: false})
    stock_2 = FirebaseTransaction.create({open: false})
    stock_3 = FirebaseTransaction.create({open: true})
    stock_4 = FirebaseTransaction.create({open: false})
    found_stocks = FirebaseTransaction.find_by({open: true})
    assert_equal 1, found_stocks.count
    assert_equal stock_3.id, found_stocks.first.id
  end

  def test_find_by_multiple_params
    stock_1 = FirebaseStock.create({symbol: "AAA", price: 3.44})
    stock_2 = FirebaseStock.create({symbol: "BBB", price: 1.22})
    stock_3 = FirebaseStock.create({symbol: "BBB", price: 1.33})
    found_stocks = FirebaseStock.find_by({symbol: "BBB", price: 1.22})
    assert_equal 1, found_stocks.count
    assert_equal stock_2.id, found_stocks.first.id
  end

  def test_updating_firebase_object
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    stock.update({price: 5.01})
    found_stock = FirebaseStock.find(stock.id)
    assert_equal 5.01, found_stock.price
  end

  def test_saving_updates_for_firebase_object
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    stock.price = 6.01
    stock.save
    found_stock = FirebaseStock.find(stock.id)
    assert_equal 6.01, found_stock.price
  end

  def test_retrieving_has_many_associations_when_they_dont_exist
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    assert_equal 0, stock.transactions.count
  end

  def test_has_many_associations
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    transactions = [1,2,3].map do |price|
      FirebaseTransaction.create({price: price, stock: stock.id})
    end
    stock.set_transactions(transactions)
    assert_equal 3, stock.transactions.count
  end

  def test_has_many_associations_return_array_of_ids
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    transactions = [1,2,3].map do |price|
      FirebaseTransaction.create({price: price, stock: stock.id})
    end
    stock.set_transactions(transactions)
    stock = FirebaseStock.find(stock.id)
    assert stock.transactions.kind_of?(Array)
  end

  def test_has_many_associations_with_just_ids
    stock = FirebaseStock.create({symbol: "AAA", price: 3.44})
    transactions = [1,2,3].map do |price|
      FirebaseTransaction.create({price: price, stock: stock.id})
    end
    stock.set_transactions(transactions.map{ |transaction| transaction.id })
    assert_equal 3, stock.transactions.count
  end

  def test_belongs_to_association_hard_coded
    stock = FirebaseStock.create({symbol: "AAA"})
    transactions = FirebaseTransaction.create({price: 1.22, stock: stock.id})
    assert_equal stock.id, transactions.stock
  end

  def test_belongs_to_association
    stock = FirebaseStock.create({symbol: "AAA"})
    transaction = FirebaseTransaction.create({price: 1.22})
    transaction.set_stock(stock)
    assert_equal stock.id, transaction.stock
  end

  def test_belongs_to_association_with_string
    stock = FirebaseStock.create({symbol: "AAA"})
    transaction = FirebaseTransaction.create({price: 1.22})
    transaction.set_stock(stock.id)
    assert_equal stock.id, transaction.stock
  end

  def test_belongs_to_association_hard_coded
    stock = FirebaseStock.create({symbol: "AAA"})
    transaction = FirebaseTransaction.create({price: 1.22, stock: stock.id})
    assert_equal stock.id, transaction.stock
  end

  def test_pushing_an_object_into_a_has_many_association_with_existing_objects
    transaction = FirebaseTransaction.create({price: 1.22})
    stock = FirebaseStock.create({symbol: "AAA"})
    stock.set_transactions(transaction)
    transaction_2 = FirebaseTransaction.create({price: 1.32, stock: stock.id})
    stock.push_transaction(transaction_2)
    assert_equal stock.transactions.count, 2
    assert_equal stock.transactions.last, transaction_2.id
  end

  def test_find_or_create_by_when_object_exists
    hash = {symbol: "AAA"}
    stock = FirebaseStock.create(hash)
    found_stock = FirebaseStock.find_or_create_by(hash)
    assert_equal stock.id, found_stock.id
  end

  def test_find_or_create_by_when_object_does_not_exists
    current_stock_count = FirebaseStock.all.count
    FirebaseStock.find_or_create_by({symbol: "ABC"})
    assert_equal current_stock_count + 1, FirebaseStock.all.count
  end
end
