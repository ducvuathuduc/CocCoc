# syntax=docker/dockerfile:1@sha256:4edf897a3ffa55b89f906fc8cc78afdb3f1834cc9c7083565e611a8a7d5fe99e
FROM mcr.microsoft.com/dotnet/sdk:10.0.401@sha256:0eeb52c76e35a5431ca707ad2bc75e38006a05393045d8532ae44c15d9474523 AS build
WORKDIR /src/backend-dotnet
COPY backend-dotnet/ ./
COPY docs/api/openapi.yaml /src/docs/api/openapi.yaml
COPY appwrite/schema/foundation.json /src/appwrite/schema/foundation.json
RUN dotnet restore CocEnglish.sln --locked-mode

FROM build AS test
RUN dotnet test CocEnglish.sln --no-restore --configuration Release

FROM build AS publish
ARG SERVICE=Progress
RUN case "$SERVICE" in Progress|Learning|AI) ;; *) exit 2 ;; esac && \
    dotnet publish "src/CocEnglish.$SERVICE/CocEnglish.$SERVICE.csproj" --configuration Release --no-restore --no-self-contained -p:UseAppHost=false -o /out && \
    printf '#!/bin/sh\nexec dotnet /app/CocEnglish.%s.dll "$@"\n' "$SERVICE" > /out/entrypoint && chmod 755 /out/entrypoint

FROM mcr.microsoft.com/dotnet/aspnet:10.0.12@sha256:0fa044f682cb7d93a5a90401a00c626c66f7b00b86922be9441f869eae039f80 AS runtime
WORKDIR /app
COPY --from=publish /out/ ./
ENV ASPNETCORE_URLS=http://+:8080 DOTNET_EnableDiagnostics=0
USER app
EXPOSE 8080
ENTRYPOINT ["/app/entrypoint"]
