scripted_ask <- function(responses) {
  index <- 0L
  function(prompt) {
    index <<- index + 1L
    if (index > length(responses)) {
      stop("scripted_ask ran out of canned responses", call. = FALSE)
    }
    responses[[index]]
  }
}

agent_fixture_session <- function(max_followup_budget = 340L, ...) {
  cap_agent_session(
    fixture_table("followup-basic"),
    budget = 500,
    policy = cap_policy(
      max_budget = 500,
      max_followup_budget = max_followup_budget
    ),
    fingerprint = fixture_fingerprint("followup-basic"),
    ...
  )
}

agent_claims_response <- function(field_ids = list("f1:table@shape#base"),
                                  text = "Answer grounded in the digest.") {
  list(
    claims = list(list(
      id = "claim-1",
      text = text,
      evidence = field_ids
    )),
    evidence = list(),
    warnings = list(),
    requests = list()
  )
}

agent_request_response <- function(field_id = "f1:table@sample#k10",
                                   reason = "Need sample rows.",
                                   budget = NULL, level = NULL) {
  request <- list(fieldId = field_id, reason = reason)
  if (!is.null(level)) request$level <- level
  if (!is.null(budget)) request$budget <- budget
  list(
    claims = list(),
    evidence = list(),
    warnings = list(),
    requests = list(request)
  )
}
