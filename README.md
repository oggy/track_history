# TrackHistory

## Introduction

Sometimes you want to track changes in a model, but in larger tables its _really_ inefficient to query against a polymorphic relationship in a single table like 'audits'.  __TrackHistory__ is a way to do this in a performant way, and its still easy!

__Not currently Rails 3 compatible__

Imagine you want to track how the name of users change over time:

    # add a mix-in to your model (yes, that's all)
    track_history

Then create a migration for a table with the following structure (generator coming soon):

    id, user_id, email_before, email_after, created_at

You will automatically get:

    user.histories
    user.histories.first.class # UserHistory

    user.histories.first.modifications # ["email"]

You can do this with any field or method.

---

## There's more

But wait, you say!  I want to use this to annotate some more information when there's changes, about the current state of the object.

    # add the field, ex: 'name' in a migration
    
    track_history do
      annotate :name
    end

    # or you can pass a block

    track_history do
      annotate(:name) { "#{name} !!!" }
    end

---

## Installation

    gem install track_history

---

## Other options

If you need to change the name of the model, you can do something like:

    track_history :model_name => 'UserAudit'

---

### License

The MIT License (see attached)
