# Image de l'API RDV : build dans le SDK, exécution dans l'image ASP.NET Core (sans SDK).
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY global.json Directory.Build.props Santinord.Rdv.sln ./
COPY src/Santinord.Rdv.Domain/*.csproj src/Santinord.Rdv.Domain/packages.lock.json src/Santinord.Rdv.Domain/
COPY src/Santinord.Rdv.Api/*.csproj src/Santinord.Rdv.Api/packages.lock.json src/Santinord.Rdv.Api/
RUN dotnet restore src/Santinord.Rdv.Api/Santinord.Rdv.Api.csproj --locked-mode
COPY src/ src/
ARG VERSION=0.0.0-docker
RUN dotnet publish src/Santinord.Rdv.Api/Santinord.Rdv.Api.csproj \
    --configuration Release --no-restore -p:Version=${VERSION} --output /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
USER app
ENTRYPOINT ["dotnet", "Santinord.Rdv.Api.dll"]
