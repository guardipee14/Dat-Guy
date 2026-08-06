enum PhoenixPackageAcquisitionStatus {

    Unknown = 0

    # A new artifact was acquired and stored successfully.
    Acquired = 1

    # A matching verified content object already existed and was reused.
    Reused = 2

    # Automatic acquisition is unavailable, but an explicit local artifact
    # may be supplied by the user.
    UserSuppliedRequired = 3

    # The provider or source could not produce an offline artifact.
    Unavailable = 4

    # The artifact may not be redistributed by Phoenix.
    NotRedistributable = 5

    # Acquisition requires an interactive provider or installer workflow.
    InteractiveOnly = 6

    # Source policy, authentication, or access restrictions blocked capture.
    SourceRestricted = 7

    # Phoenix has no compatible acquisition adapter for this package.
    Unsupported = 8

    # Acquisition was attempted but failed.
    Failed = 9

    # Acquisition was cancelled before completion.
    Cancelled = 10
}
