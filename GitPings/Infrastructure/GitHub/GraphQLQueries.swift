import Foundation

/// GraphQL document string constants for the MVP field set (REFRESH-4, ADR-002).
/// Kept as strings so the spike can land without a codegen dependency.
public enum GraphQLQueries {
    public static let endpoint = URL(string: "https://api.github.com/graphql")!

    /// FILTER-4: resolve authenticated login before compiling search qualifiers.
    public static let viewerLogin = #"""
    query GitPingsViewerLogin {
      viewer {
        id
        login
      }
      rateLimit {
        limit
        remaining
        resetAt
        cost
      }
    }
    """#

    /// REPO discovery sketch via viewer repositories.
    /// Live spike must confirm this matches App installation visibility;
    /// otherwise fall back to REST installation listing (ADR-002).
    public static let viewerRepositoriesPage = #"""
    query GitPingsViewerRepositories($first: Int!, $after: String) {
      viewer {
        repositories(
          first: $first
          after: $after
          affiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]
          ownerAffiliations: [OWNER, COLLABORATOR, ORGANIZATION_MEMBER]
          orderBy: { field: UPDATED_AT, direction: DESC }
        ) {
          pageInfo {
            hasNextPage
            endCursor
          }
          nodes {
            id
            name
            nameWithOwner
            isPrivate
            owner {
              login
              __typename
            }
          }
        }
      }
      rateLimit {
        limit
        remaining
        resetAt
        cost
      }
    }
    """#

    /// FILTER-5 / PR-4: open PR search with CI rollup + merge fields.
    public static let pullRequestSearchPage = #"""
    query GitPingsPullRequestSearch($query: String!, $first: Int!, $after: String) {
      search(query: $query, type: ISSUE, first: $first, after: $after) {
        pageInfo {
          hasNextPage
          endCursor
        }
        nodes {
          __typename
          ... on PullRequest {
            id
            number
            title
            url
            state
            merged
            headRefName
            baseRefName
            updatedAt
            mergeable
            mergeStateStatus
            author {
              login
            }
            repository {
              id
              nameWithOwner
              isPrivate
            }
            commits(last: 1) {
              nodes {
                commit {
                  statusCheckRollup {
                    state
                    contexts {
                      totalCount
                    }
                  }
                }
              }
            }
          }
        }
      }
      rateLimit {
        limit
        remaining
        resetAt
        cost
      }
    }
    """#

    /// CHANGE-3A: targeted lookup before treating open-search disappearance as closed/merged.
    public static let pullRequestByNodeID = #"""
    query GitPingsPullRequestByID($id: ID!) {
      node(id: $id) {
        __typename
        ... on PullRequest {
          id
          number
          title
          url
          state
          merged
          headRefName
          baseRefName
          updatedAt
          mergeable
          mergeStateStatus
          author {
            login
          }
          repository {
            id
            nameWithOwner
            isPrivate
          }
          commits(last: 1) {
            nodes {
              commit {
                statusCheckRollup {
                  state
                  contexts {
                    totalCount
                  }
                }
              }
            }
          }
        }
      }
      rateLimit {
        limit
        remaining
        resetAt
        cost
      }
    }
    """#
}
