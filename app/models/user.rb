require 'digest'

class User < ApplicationRecord
  # ATTENZIONE: SHA1 senza "sale" è debole. Va bene SOLO per studiare (è quello che
  # usa il libro). In un sito vero si usa has_secure_password con la gem bcrypt.
  attr_accessor :password

  validates :email, uniqueness: true
  validates :email, length: { in: 5..50 }
  validates :email, format: { with: /\A[^@][\w.-]+@[\w.-]+[.][a-z]{2,4}\z/i }
  validates :password, confirmation: true, if: :password_required?
  validates :password, length: { in: 4..20 }, if: :password_required?
  validates :password, presence: true, if: :password_required?

  # `dependent: :destroy` non è nel libro: senza, eliminare un utente con profilo fallisce
  # per la chiave esterna (profiles.user_id non può essere NULL).
  has_one :profile, dependent: :destroy
  has_many :articles, -> { order 'published_at DESC, title ASC' },
           dependent: :nullify
  has_many :replies, through: :articles, source: :comments

  before_save :encrypt_new_password

  def self.authenticate(email, password)
    user = find_by email: email
    return user if user && user.authenticated?(password)
  end

  def authenticated?(password)
    self.hashed_password == encrypt(password)
  end

  protected

  def encrypt_new_password
    return if password.blank?
    self.hashed_password = encrypt(password)
  end

  def password_required?
    hashed_password.blank? || password.present?
  end

  def encrypt(string)
    Digest::SHA1.hexdigest(string)
  end
end
