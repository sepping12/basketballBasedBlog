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

  # Un token casuale e unico, impostato alla creazione. Aggiunge regenerate_draft_article_token.
  # Serve a costruire l'indirizzo segreto con cui l'utente crea bozze scrivendo un'email (Action Mailbox).
  has_secure_token :draft_article_token

  before_save :encrypt_new_password

  def self.authenticate(email, password)
    user = find_by email: email
    return user if user && user.authenticated?(password)
  end

  def authenticated?(password)
    self.hashed_password == encrypt(password)
  end

  # L'indirizzo email personale per le bozze: <token>@drafts.example.com
  def draft_article_email
    "#{draft_article_token}@#{Rails.configuration.x.drafts_domain}"
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
