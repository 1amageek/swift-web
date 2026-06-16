@resultBuilder
public enum AppServiceBuilder {
    public static func buildBlock(_ services: any AppServices...) -> AppServicesGroup {
        AppServicesGroup(services)
    }

    public static func buildOptional(_ service: (any AppServices)?) -> AppServicesGroup {
        AppServicesGroup(service.map { [$0] } ?? [])
    }

    public static func buildEither(first service: any AppServices) -> any AppServices {
        service
    }

    public static func buildEither(second service: any AppServices) -> any AppServices {
        service
    }
}
